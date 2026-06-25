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

  const PushNotificationsState({
    this.navigationRequest,
  });

  PushNotificationsState copyWith({
    PushNavigationRequest? navigationRequest,
    bool clearNavigation = false,
  }) {
    return PushNotificationsState(
      navigationRequest:
          clearNavigation ? null : navigationRequest ?? this.navigationRequest,
    );
  }
}

class PushNotificationsController extends StateNotifier<PushNotificationsState>
    with WidgetsBindingObserver {
  final PushMessagingService _pushMessagingService;
  final RegisterPushTokenUseCase _registerPushTokenUseCase;
  final GetRoomUseCase _getRoomUseCase;
  final GetNotificationThreadContextUseCase
      _getNotificationThreadContextUseCase;
  final MarkNotificationAsReadUseCase _markNotificationAsReadUseCase;
  final String? Function() _readAuthToken;
  final bool Function() _supportsPushPlatform;
  final String Function() _platformName;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<PushNotificationPayload>? _messageOpenedSubscription;
  Future<void>? _navigationInFlight;
  String? _registeredPushToken;
  PushNotificationPayload? _pendingInitialPayload;
  bool _started = false;
  bool _contentReady = false;
  bool _handledInitialPayload = false;

  PushNotificationsController(
    this._pushMessagingService,
    this._registerPushTokenUseCase,
    this._getRoomUseCase,
    this._getNotificationThreadContextUseCase,
    this._markNotificationAsReadUseCase,
    this._readAuthToken, {
    bool Function()? supportsPushPlatform,
    String Function()? platformName,
  })  : _supportsPushPlatform = supportsPushPlatform ??
            (() => Platform.isIOS || Platform.isAndroid),
        _platformName =
            platformName ?? (() => Platform.isIOS ? 'ios' : 'android'),
        super(const PushNotificationsState());

  void start() {
    if (_started) {
      return;
    }

    _started = true;
    WidgetsBinding.instance.addObserver(this);

    _tokenRefreshSubscription =
        _pushMessagingService.onTokenRefresh.listen((token) {
      final authToken = _readAuthToken();
      if (authToken == null || authToken.isEmpty) {
        return;
      }

      unawaited(_registerPushToken(token: token, force: true));
    });

    _messageOpenedSubscription =
        _pushMessagingService.onMessageOpenedApp.listen((payload) {
      if (_readAuthToken()?.isNotEmpty != true) {
        return;
      }

      unawaited(_queueNavigationForPayload(payload));
    });
  }

  Future<void> handleAuthTokenChanged(String? authToken) async {
    if (authToken == null || authToken.isEmpty) {
      _registeredPushToken = null;
      _pendingInitialPayload = null;
      _contentReady = false;
      _handledInitialPayload = false;
      state = state.copyWith(clearNavigation: true);
      return;
    }

    await _registerPushToken();
    await _handleInitialPayloadOnce();
  }

  Future<void> markContentReady() async {
    _contentReady = true;
    await _drainPendingInitialPayloadIfReady();
  }

  void consumeNavigation() {
    state = state.copyWith(clearNavigation: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    final authToken = _readAuthToken();
    if (authToken == null || authToken.isEmpty) {
      return;
    }

    unawaited(_registerPushToken());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_tokenRefreshSubscription?.cancel());
    unawaited(_messageOpenedSubscription?.cancel());
    super.dispose();
  }

  Future<void> _handleInitialPayloadOnce() async {
    if (_handledInitialPayload) {
      return;
    }

    _handledInitialPayload = true;
    final payload = await _pushMessagingService.getInitialPayload();
    if (payload == null) {
      return;
    }

    _pendingInitialPayload = payload;
    await _drainPendingInitialPayloadIfReady();
  }

  Future<void> _drainPendingInitialPayloadIfReady() async {
    final payload = _pendingInitialPayload;
    if (!_contentReady || payload == null) {
      return;
    }

    final authToken = _readAuthToken();
    if (authToken == null || authToken.isEmpty) {
      return;
    }

    _pendingInitialPayload = null;
    await _queueNavigationForPayload(payload);
  }

  bool _isAuthorizedStatus(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  Future<void> _registerPushToken({
    String? token,
    bool force = false,
  }) async {
    if (!_supportsPushPlatform()) {
      return;
    }

    var settings = await _pushMessagingService.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      settings = await _pushMessagingService.requestPermission();
    }

    // Do not gate registration on the authorization status. On Android the
    // FCM token is valid before POST_NOTIFICATIONS is granted, so we still
    // register it: the backend then has a deliverable token and pushes arrive
    // the moment the user enables notifications, with no fresh registration
    // needed. (On iOS getToken() returns null until permission is granted, so
    // this naturally stays a no-op there.)
    if (!_isAuthorizedStatus(settings.authorizationStatus)) {
      debugPrint(
        'push/register: notifications not authorized '
        '(status=${settings.authorizationStatus}); registering token anyway',
      );
    }

    final resolvedToken = token ?? await _pushMessagingService.getToken();
    if (resolvedToken == null || resolvedToken.isEmpty) {
      debugPrint(
        'push/register: no FCM token (getToken returned null/empty) — '
        'check Google Play Services availability on this device',
      );
      return;
    }

    if (!force && _registeredPushToken == resolvedToken) {
      return;
    }

    try {
      await _registerPushTokenUseCase(
        token: resolvedToken,
        platform: _platformName(),
      );
      _registeredPushToken = resolvedToken;
      debugPrint('push/register: token registered (platform=${_platformName()})');
    } catch (error, stackTrace) {
      debugPrint('push/register failed: $error');
      debugPrint('$stackTrace');
    }
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
