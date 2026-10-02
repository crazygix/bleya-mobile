import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/push_notification_payload.dart';
import '../domain/entities/room.dart';
import '../services/push_messaging_service.dart';
import '../use_cases/notification/get_notification_thread_context_use_case.dart';
import '../use_cases/notification/mark_notification_as_read_use_case.dart';
import '../use_cases/notification/register_push_token_use_case.dart';
import '../use_cases/room/get_room_use_case.dart';

sealed class PushNavigationRequest {
  const PushNavigationRequest();
}

class OpenRoomPushNavigationRequest extends PushNavigationRequest {
  final Room room;

  const OpenRoomPushNavigationRequest({
    required this.room,
  });
}

class OpenThreadPushNavigationRequest extends PushNavigationRequest {
  final NotificationThreadContext threadContext;

  const OpenThreadPushNavigationRequest({
    required this.threadContext,
  });
}

class PushNotificationsState {
  final PushNavigationRequest? navigationRequest;
  final bool notificationsDenied;
  final bool notificationsBannerDismissed;

  /// Whether the banner's button can still show Android's one extra
  /// permission dialog. Otherwise it opens the app's settings.
  final bool canRequestPermissionAgain;

  const PushNotificationsState({
    this.navigationRequest,
    this.notificationsDenied = false,
    this.notificationsBannerDismissed = false,
    this.canRequestPermissionAgain = false,
  });

  bool get showNotificationsBanner =>
      notificationsDenied && !notificationsBannerDismissed;

  PushNotificationsState copyWith({
    PushNavigationRequest? navigationRequest,
    bool clearNavigation = false,
    bool? notificationsDenied,
    bool? notificationsBannerDismissed,
    bool? canRequestPermissionAgain,
  }) {
    return PushNotificationsState(
      navigationRequest:
          clearNavigation ? null : navigationRequest ?? this.navigationRequest,
      notificationsDenied: notificationsDenied ?? this.notificationsDenied,
      notificationsBannerDismissed:
          notificationsBannerDismissed ?? this.notificationsBannerDismissed,
      canRequestPermissionAgain:
          canRequestPermissionAgain ?? this.canRequestPermissionAgain,
    );
  }
}

class PushNotificationsController extends StateNotifier<PushNotificationsState>
    with WidgetsBindingObserver {
  /// How long registration waits before trying again while iOS hasn't
  /// received the APNs token. After the last one, returning to the app or a
  /// new token from Firebase registers it.
  static const _tokenRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 32),
  ];

  /// A refusal that comes back faster than anyone could read a dialog means
  /// Android didn't show one.
  static const _refusedWithoutDialog = Duration(milliseconds: 500);

  final PushMessagingService _pushMessagingService;
  final RegisterPushTokenUseCase _registerPushTokenUseCase;
  final GetRoomUseCase _getRoomUseCase;
  final GetNotificationThreadContextUseCase
      _getNotificationThreadContextUseCase;
  final MarkNotificationAsReadUseCase _markNotificationAsReadUseCase;
  final String? Function() _readAuthToken;
  final bool Function() _supportsPushPlatform;
  final String Function() _platformName;
  final Future<void> Function()? _openAppSettings;
  final DateTime Function() _now;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<PushNotificationPayload>? _messageOpenedSubscription;
  Future<void>? _navigationInFlight;
  String? _registeredPushToken;
  PushNotificationPayload? _pendingInitialPayload;
  bool _started = false;
  bool _contentReady = false;

  // The notification that launched the app opens once per app run. It is
  // not handled again after signing out and back in.
  bool _handledInitialPayload = false;

  // Changes at every sign-out, so work that started in an earlier session
  // records nothing.
  int _session = 0;

  Timer? _tokenRetryTimer;
  int _tokenRetries = 0;

  // The permission request or banner action under way. Android allows one
  // permission request at a time.
  Future<void>? _permissionRequest;

  // Whether the app has asked for permission, or found it had asked before,
  // in this app run. Until then a "denied" may just mean "never asked", so
  // the banner stays hidden.
  bool _permissionChecked = false;

  PushNotificationsController(
    this._pushMessagingService,
    this._registerPushTokenUseCase,
    this._getRoomUseCase,
    this._getNotificationThreadContextUseCase,
    this._markNotificationAsReadUseCase,
    this._readAuthToken, {
    bool Function()? supportsPushPlatform,
    String Function()? platformName,
    Future<void> Function()? openAppSettings,
    DateTime Function()? now,
  })  : _supportsPushPlatform = supportsPushPlatform ??
            (() => Platform.isIOS || Platform.isAndroid),
        _platformName =
            platformName ?? (() => Platform.isIOS ? 'ios' : 'android'),
        _openAppSettings = openAppSettings,
        _now = now ?? DateTime.now,
        super(const PushNotificationsState());

  bool get _isSignedIn => _readAuthToken()?.isNotEmpty == true;

  bool get _isAndroid => _platformName() == 'android';

  void start() {
    if (_started) {
      return;
    }

    _started = true;
    WidgetsBinding.instance.addObserver(this);

    _tokenRefreshSubscription =
        _pushMessagingService.onTokenRefresh.listen((token) {
      if (!_isSignedIn) {
        return;
      }

      unawaited(_registerPushToken(token: token, force: true));
    });

    _messageOpenedSubscription =
        _pushMessagingService.onMessageOpenedApp.listen((payload) {
      if (!_isSignedIn) {
        return;
      }

      unawaited(_queueNavigationForPayload(payload));
    });
  }

  Future<void> handleAuthTokenChanged(String? authToken) async {
    if (authToken == null || authToken.isEmpty) {
      _session++;
      _registeredPushToken = null;
      _pendingInitialPayload = null;
      _contentReady = false;
      _cancelTokenRetry();
      state = state.copyWith(clearNavigation: true);
      return;
    }

    // Each runs on its own: a token that isn't ready or a slow registration
    // doesn't hold up opening the notification that launched the app.
    await Future.wait([
      _handleInitialPayloadOnce(),
      _registerPushToken(),
      _refreshPermissionStatus(),
    ]);
  }

  /// The device is back online, or the stored token has been read at launch:
  /// a token deletion left over from a sign-out can go through now.
  void handleConnectionRestored() {
    _retryPendingTokenDeletion();
  }

  Future<void> markContentReady() async {
    _contentReady = true;
    await _drainPendingInitialPayloadIfReady();
  }

  /// Asks for notification permission if nobody has decided yet: when iOS
  /// reports "not determined", or Android reports "denied" and the app never
  /// asked (Android 13+ reports a permission nobody asked for as denied).
  /// The chat list calls it when it first shows. It asks once per install;
  /// a refusal shows the "Notifications are off" banner instead.
  Future<void> requestPermissionIfUndecided() {
    return _runPermissionRequest(_requestPermissionIfUndecided);
  }

  /// The banner's button. On Android it first shows the system dialog once
  /// more, as Android allows once after a refusal. When Android answers
  /// without showing it, or once it has been used, the button opens the
  /// app's settings, as it always does on iOS.
  Future<void> turnOnNotifications() {
    return _runPermissionRequest(_turnOnNotifications);
  }

  void consumeNavigation() {
    state = state.copyWith(clearNavigation: true);
  }

  void _updateNotificationsDenied(
    bool denied, {
    required bool canRequestAgain,
  }) {
    if (!mounted) {
      return;
    }
    // When notifications get (re-)enabled, also clear any prior dismissal so
    // the banner can resurface if the user turns them off again later.
    final dismissed = denied ? state.notificationsBannerDismissed : false;
    if (state.notificationsDenied == denied &&
        state.notificationsBannerDismissed == dismissed &&
        state.canRequestPermissionAgain == canRequestAgain) {
      return;
    }
    state = state.copyWith(
      notificationsDenied: denied,
      notificationsBannerDismissed: dismissed,
      canRequestPermissionAgain: canRequestAgain,
    );
  }

  void dismissNotificationsBanner() {
    if (state.notificationsBannerDismissed) {
      return;
    }
    state = state.copyWith(notificationsBannerDismissed: true);
  }

  Future<void> openNotificationSettings() async {
    await _openAppSettings?.call();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    if (!_isSignedIn) {
      _retryPendingTokenDeletion();
      return;
    }

    unawaited(_registerPushToken());
    // Notifications may have been turned on or off in Settings meanwhile.
    unawaited(_refreshPermissionStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTokenRetry();
    unawaited(_tokenRefreshSubscription?.cancel());
    unawaited(_messageOpenedSubscription?.cancel());
    super.dispose();
  }

  /// While signed out, finishes deleting the FCM token of a session whose
  /// deletion didn't go through at sign-out.
  void _retryPendingTokenDeletion() {
    if (!mounted || !_supportsPushPlatform() || _isSignedIn) {
      return;
    }
    unawaited(_pushMessagingService.retryPendingTokenDeletion());
  }

  Future<void> _runPermissionRequest(Future<void> Function() request) {
    return _permissionRequest ??= request().whenComplete(() {
      _permissionRequest = null;
    });
  }

  Future<void> _requestPermissionIfUndecided() async {
    if (!_supportsPushPlatform() || !_isSignedIn) {
      return;
    }

    AuthorizationStatus? status;
    try {
      final settings = await _pushMessagingService.getNotificationSettings();
      status = settings.authorizationStatus;
      final undecided = status == AuthorizationStatus.notDetermined ||
          (status == AuthorizationStatus.denied &&
              !await _pushMessagingService.hasRequestedPermission());
      if (undecided) {
        final answer = await _pushMessagingService.requestPermission();
        status = answer.authorizationStatus;
        await _pushMessagingService.markPermissionRequested();
      }
    } catch (error) {
      // Not marked as asked, so the next sign-in or launch asks again.
      debugPrint('push/permission: asking for permission failed: $error');
      status = null;
    }

    _permissionChecked = true;
    if (status == null) {
      await _refreshPermissionStatus();
    } else {
      await _showPermissionStatus(status);
    }
  }

  Future<void> _turnOnNotifications() async {
    if (!_supportsPushPlatform()) {
      return;
    }

    if (_isAndroid &&
        !await _pushMessagingService.hasRequestedPermissionAgain()) {
      try {
        final askedAt = _now();
        final answer = await _pushMessagingService.requestPermission();
        final answeredAfter = _now().difference(askedAt);
        await _pushMessagingService.markPermissionRequestedAgain();
        await _showPermissionStatus(answer.authorizationStatus);
        if (answer.authorizationStatus != AuthorizationStatus.denied ||
            answeredAfter >= _refusedWithoutDialog) {
          // Allowed, or refused in the dialog: the next tap opens Settings.
          return;
        }
        // Android refused without showing the dialog.
      } catch (error) {
        debugPrint('push/permission: asking again failed: $error');
      }
    }

    await openNotificationSettings();
  }

  /// Reads the permission state again and shows or hides the banner.
  Future<void> _refreshPermissionStatus() async {
    if (!_supportsPushPlatform()) {
      return;
    }
    try {
      final settings = await _pushMessagingService.getNotificationSettings();
      await _showPermissionStatus(settings.authorizationStatus);
    } catch (error) {
      debugPrint('push/permission: reading the permission failed: $error');
    }
  }

  /// Shows the banner for a refusal: notifications are denied after the app
  /// has asked.
  Future<void> _showPermissionStatus(AuthorizationStatus status) async {
    final denied = _permissionChecked && status == AuthorizationStatus.denied;
    final canRequestAgain = denied &&
        _isAndroid &&
        !await _pushMessagingService.hasRequestedPermissionAgain();
    _updateNotificationsDenied(denied, canRequestAgain: canRequestAgain);
  }

  Future<void> _handleInitialPayloadOnce() async {
    if (_handledInitialPayload) {
      return;
    }

    _handledInitialPayload = true;
    try {
      final payload = await _pushMessagingService.getInitialPayload();
      if (payload == null) {
        return;
      }

      _pendingInitialPayload = payload;
      await _drainPendingInitialPayloadIfReady();
    } catch (error) {
      debugPrint('push/initial-message failed: $error');
    }
  }

  Future<void> _drainPendingInitialPayloadIfReady() async {
    final payload = _pendingInitialPayload;
    if (!_contentReady || payload == null) {
      return;
    }

    if (!_isSignedIn) {
      return;
    }

    _pendingInitialPayload = null;
    await _queueNavigationForPayload(payload);
  }

  /// Registers this device's FCM token for the signed-in account. Never
  /// throws. It registers whatever the notification permission: the token
  /// is valid without it, so pushes arrive the moment the user allows them.
  Future<void> _registerPushToken({
    String? token,
    bool force = false,
  }) async {
    if (!_supportsPushPlatform()) {
      return;
    }

    final session = _session;
    final String? resolvedToken;
    try {
      resolvedToken = token ?? await _pushMessagingService.getToken();
    } on ApnsTokenNotReadyException {
      debugPrint(
        'push/register: no FCM token yet (iOS has no APNs token); '
        'trying again shortly',
      );
      if (session == _session && mounted) {
        _scheduleTokenRetry();
      }
      return;
    } catch (error) {
      debugPrint('push/register: getting the FCM token failed: $error');
      return;
    }

    // Signed out meanwhile.
    if (session != _session || !mounted) {
      return;
    }

    if (resolvedToken == null || resolvedToken.isEmpty) {
      debugPrint(
        'push/register: no FCM token (getToken returned null/empty) — '
        'check Google Play Services availability on this device',
      );
      return;
    }
    _cancelTokenRetry();

    if (!force && _registeredPushToken == resolvedToken) {
      return;
    }

    try {
      // This app keeps the iOS app-icon badge current, so the server may
      // send the badge count in pushes.
      await _registerPushTokenUseCase(
        token: resolvedToken,
        platform: _platformName(),
        badge: true,
      );
      if (session != _session) {
        return;
      }
      _registeredPushToken = resolvedToken;
      // The token now belongs to this account. A deletion left over from an
      // earlier sign-out would only stop this account's pushes.
      unawaited(_pushMessagingService.clearPendingTokenDeletion());
      debugPrint(
          'push/register: token registered (platform=${_platformName()})');
    } catch (error, stackTrace) {
      debugPrint('push/register failed: $error');
      debugPrint('$stackTrace');
    }
  }

  void _scheduleTokenRetry() {
    if (_tokenRetryTimer != null || _tokenRetries >= _tokenRetryDelays.length) {
      return;
    }
    final delay = _tokenRetryDelays[_tokenRetries++];
    _tokenRetryTimer = Timer(delay, () {
      _tokenRetryTimer = null;
      if (!mounted || !_isSignedIn) {
        return;
      }
      unawaited(_registerPushToken());
    });
  }

  void _cancelTokenRetry() {
    _tokenRetryTimer?.cancel();
    _tokenRetryTimer = null;
    _tokenRetries = 0;
  }

  Future<void> _queueNavigationForPayload(
    PushNotificationPayload payload,
  ) async {
    final existingNavigation = _navigationInFlight;
    if (existingNavigation != null) {
      await existingNavigation;
    }

    final navigation = _prepareNavigation(payload);
    _navigationInFlight = navigation;

    try {
      await navigation;
    } finally {
      if (identical(_navigationInFlight, navigation)) {
        _navigationInFlight = null;
      }
    }
  }

  Future<void> _prepareNavigation(PushNotificationPayload payload) async {
    try {
      final request = await _buildNavigationRequest(payload);
      if (request != null) {
        state = state.copyWith(navigationRequest: request);
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('push/navigation preparation failed: $error');
        print(stackTrace);
      }
    }
  }

  Future<PushNavigationRequest?> _buildNavigationRequest(
    PushNotificationPayload payload,
  ) async {
    if (payload.isReply) {
      final threadId = payload.threadId;
      if (threadId == null) {
        return null;
      }

      await _markReplyNotificationRead(payload.notificationId);

      final threadContext = await _getNotificationThreadContextUseCase(
        roomId: payload.roomId,
        threadId: threadId,
      );

      return OpenThreadPushNavigationRequest(
        threadContext: threadContext,
      );
    }

    final room = await _getRoomUseCase(payload.roomId);
    return OpenRoomPushNavigationRequest(room: room);
  }

  Future<void> _markReplyNotificationRead(String? notificationId) async {
    if (notificationId == null || notificationId.isEmpty) {
      return;
    }

    try {
      await _markNotificationAsReadUseCase(notificationId);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('push/mark-reply-read failed: $error');
        print(stackTrace);
      }
    }
  }
}
