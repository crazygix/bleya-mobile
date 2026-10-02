import 'dart:async';

import 'package:bleya/controllers/push_notifications_controller.dart';
import 'package:bleya/domain/entities/message.dart';
import 'package:bleya/domain/entities/push_notification_payload.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/services/push_messaging_service.dart';
import 'package:bleya/use_cases/notification/get_notification_thread_context_use_case.dart';
import 'package:bleya/use_cases/notification/mark_notification_as_read_use_case.dart';
import 'package:bleya/use_cases/notification/register_push_token_use_case.dart';
import 'package:bleya/use_cases/room/get_room_use_case.dart';
import 'package:fake_async/fake_async.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPushMessagingService extends Mock implements PushMessagingService {}

class MockRegisterPushTokenUseCase extends Mock
    implements RegisterPushTokenUseCase {}

class MockGetRoomUseCase extends Mock implements GetRoomUseCase {}

class MockGetNotificationThreadContextUseCase extends Mock
    implements GetNotificationThreadContextUseCase {}

class MockMarkNotificationAsReadUseCase extends Mock
    implements MarkNotificationAsReadUseCase {}

NotificationSettings _settings(AuthorizationStatus status) {
  return NotificationSettings(
    authorizationStatus: status,
    alert: AppleNotificationSetting.notSupported,
    announcement: AppleNotificationSetting.notSupported,
    badge: AppleNotificationSetting.notSupported,
    carPlay: AppleNotificationSetting.notSupported,
    lockScreen: AppleNotificationSetting.notSupported,
    notificationCenter: AppleNotificationSetting.notSupported,
    showPreviews: AppleShowPreviewSetting.notSupported,
    sound: AppleNotificationSetting.notSupported,
    timeSensitive: AppleNotificationSetting.notSupported,
    criticalAlert: AppleNotificationSetting.notSupported,
    providesAppNotificationSettings: AppleNotificationSetting.notSupported,
  );
}

final _authorizedNotificationSettings =
    _settings(AuthorizationStatus.authorized);
final _deniedNotificationSettings = _settings(AuthorizationStatus.denied);
final _notDeterminedNotificationSettings =
    _settings(AuthorizationStatus.notDetermined);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPushMessagingService mockPushMessagingService;
  late MockRegisterPushTokenUseCase mockRegisterPushTokenUseCase;
  late MockGetRoomUseCase mockGetRoomUseCase;
  late MockGetNotificationThreadContextUseCase
      mockGetNotificationThreadContextUseCase;
  late MockMarkNotificationAsReadUseCase mockMarkNotificationAsReadUseCase;
  late StreamController<String> tokenRefreshController;
  late StreamController<PushNotificationPayload> messageOpenedController;
  late PushNotificationsController controller;
  late String? authToken;
  late int openAppSettingsCalls;
  late String platform;
  late DateTime clock;
  // The "asked for permission" flags in secure storage.
  late bool askedForPermission;
  late bool askedForPermissionAgain;

  final testRoom = Room(id: 'room-1', name: 'General');
  final testMessage = Message(
    id: 'thread-1',
    roomId: 'room-1',
    userId: 'user-2',
    username: 'alice',
    text: 'Parent message',
    createdAt: DateTime(2026, 1, 1),
  );
  final initialMessagePayload = PushNotificationPayload(
    type: PushNotificationType.message,
    roomId: 'room-1',
    messageId: 'message-1',
    senderId: 'user-1',
  );
  final replyPayload = PushNotificationPayload(
    type: PushNotificationType.reply,
    roomId: 'room-1',
    messageId: 'message-2',
    senderId: 'user-2',
    threadId: 'thread-1',
    notificationId: 'notification-1',
  );

  PushNotificationsController createController() {
    return PushNotificationsController(
      mockPushMessagingService,
      mockRegisterPushTokenUseCase,
      mockGetRoomUseCase,
      mockGetNotificationThreadContextUseCase,
      mockMarkNotificationAsReadUseCase,
      () => authToken,
      supportsPushPlatform: () => true,
      platformName: () => platform,
      openAppSettings: () async {
        openAppSettingsCalls++;
      },
      now: () => clock,
    );
  }

  setUp(() {
    mockPushMessagingService = MockPushMessagingService();
    mockRegisterPushTokenUseCase = MockRegisterPushTokenUseCase();
    mockGetRoomUseCase = MockGetRoomUseCase();
    mockGetNotificationThreadContextUseCase =
        MockGetNotificationThreadContextUseCase();
    mockMarkNotificationAsReadUseCase = MockMarkNotificationAsReadUseCase();
    tokenRefreshController = StreamController<String>.broadcast();
    messageOpenedController =
        StreamController<PushNotificationPayload>.broadcast();
    authToken = 'auth-token';
    openAppSettingsCalls = 0;
    platform = 'ios';
    clock = DateTime(2026, 10, 1, 9);
    askedForPermission = false;
    askedForPermissionAgain = false;

    when(() => mockPushMessagingService.getNotificationSettings())
        .thenAnswer((_) async => _authorizedNotificationSettings);
    when(() => mockPushMessagingService.requestPermission())
        .thenAnswer((_) async => _deniedNotificationSettings);
    when(() => mockPushMessagingService.hasRequestedPermission())
        .thenAnswer((_) async => askedForPermission);
    when(() => mockPushMessagingService.markPermissionRequested())
        .thenAnswer((_) async => askedForPermission = true);
    when(() => mockPushMessagingService.hasRequestedPermissionAgain())
        .thenAnswer((_) async => askedForPermissionAgain);
    when(() => mockPushMessagingService.markPermissionRequestedAgain())
        .thenAnswer((_) async => askedForPermissionAgain = true);
    when(() => mockPushMessagingService.getToken())
        .thenAnswer((_) async => 'push-token');
    when(() => mockPushMessagingService.getInitialPayload())
        .thenAnswer((_) async => null);
    when(() => mockPushMessagingService.onTokenRefresh)
        .thenAnswer((_) => tokenRefreshController.stream);
    when(() => mockPushMessagingService.onMessageOpenedApp)
        .thenAnswer((_) => messageOpenedController.stream);
    when(() => mockPushMessagingService.retryPendingTokenDeletion())
        .thenAnswer((_) async {});
    when(() => mockPushMessagingService.clearPendingTokenDeletion())
        .thenAnswer((_) async {});

    when(() => mockRegisterPushTokenUseCase(
          token: any(named: 'token'),
          platform: any(named: 'platform'),
          badge: any(named: 'badge'),
        )).thenAnswer((_) async {});

    controller = createController();
  });

  tearDown(() async {
    controller.dispose();
    await tokenRefreshController.close();
    await messageOpenedController.close();
  });

  void verifyRegistered(String token, {int times = 1}) {
    verify(() => mockRegisterPushTokenUseCase(
          token: token,
          platform: platform,
          badge: true,
        )).called(times);
  }

  void verifyNothingRegistered() {
    verifyNever(() => mockRegisterPushTokenUseCase(
          token: any(named: 'token'),
          platform: any(named: 'platform'),
          badge: any(named: 'badge'),
        ));
  }

  void answerPermission(NotificationSettings settings) {
    when(() => mockPushMessagingService.getNotificationSettings())
        .thenAnswer((_) async => settings);
  }

  test('waits for content readiness before navigating initial push', () async {
    when(() => mockPushMessagingService.getInitialPayload())
        .thenAnswer((_) async => initialMessagePayload);
    when(() => mockGetRoomUseCase('room-1')).thenAnswer((_) async => testRoom);

    controller.start();
    await controller.handleAuthTokenChanged(authToken);

    expect(controller.state.navigationRequest, isNull);
    verifyRegistered('push-token');

    await controller.markContentReady();

    final request = controller.state.navigationRequest;
    expect(request, isA<OpenRoomPushNavigationRequest>());
    expect((request as OpenRoomPushNavigationRequest).room, testRoom);
    verify(() => mockGetRoomUseCase('room-1')).called(1);
  });

  test('prepares thread navigation for reply pushes and marks alert as read',
      () async {
    final threadContext = NotificationThreadContext(
      room: testRoom,
      parentMessage: testMessage,
    );
    when(() => mockMarkNotificationAsReadUseCase('notification-1'))
        .thenAnswer((_) async {});
    when(() => mockGetNotificationThreadContextUseCase(
          roomId: 'room-1',
          threadId: 'thread-1',
        )).thenAnswer((_) async => threadContext);

    controller.start();
    await controller.handleAuthTokenChanged(authToken);
    await controller.markContentReady();

    messageOpenedController.add(replyPayload);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    final request = controller.state.navigationRequest;
    expect(request, isA<OpenThreadPushNavigationRequest>());
    expect(
      (request as OpenThreadPushNavigationRequest).threadContext,
      threadContext,
    );
    verify(() => mockMarkNotificationAsReadUseCase('notification-1')).called(1);
    verify(() => mockGetNotificationThreadContextUseCase(
          roomId: 'room-1',
          threadId: 'thread-1',
        )).called(1);
  });

  test('re-registers token when Firebase rotates it', () async {
    controller.start();
    await controller.handleAuthTokenChanged(authToken);
    clearInteractions(mockRegisterPushTokenUseCase);

    tokenRefreshController.add('rotated-token');
    await Future<void>.delayed(const Duration(milliseconds: 1));

    verifyRegistered('rotated-token');
  });

  test('registers token even when notification permission is denied', () async {
    // The FCM token is valid without notification permission (notably on
    // Android), so registration must not be gated on the authorization status;
    // otherwise the backend never gets a deliverable token for that device.
    answerPermission(_deniedNotificationSettings);

    controller.start();
    await controller.handleAuthTokenChanged(authToken);

    verifyRegistered('push-token');
  });

  test('asks the server for badge counts, as the app keeps the iOS badge',
      () async {
    controller.start();
    await controller.handleAuthTokenChanged(authToken);

    verify(() => mockRegisterPushTokenUseCase(
          token: 'push-token',
          platform: 'ios',
          badge: true,
        )).called(1);
  });

  test('skips registration when no FCM token is available', () async {
    when(() => mockPushMessagingService.getToken())
        .thenAnswer((_) async => null);

    controller.start();
    await controller.handleAuthTokenChanged(authToken);

    verifyNothingRegistered();
  });

  test('flags notifications denied and shows the banner until dismissed',
      () async {
    answerPermission(_deniedNotificationSettings);
    askedForPermission = true;

    controller.start();
    await controller.handleAuthTokenChanged(authToken);
    await controller.requestPermissionIfUndecided();

    expect(controller.state.notificationsDenied, isTrue);
    expect(controller.state.showNotificationsBanner, isTrue);

    controller.dismissNotificationsBanner();

    expect(controller.state.notificationsDenied, isTrue);
    expect(controller.state.showNotificationsBanner, isFalse);
  });

  test('does not show the banner when notifications are authorized', () async {
    controller.start();
    await controller.handleAuthTokenChanged(authToken);
    await controller.requestPermissionIfUndecided();

    expect(controller.state.notificationsDenied, isFalse);
    expect(controller.state.showNotificationsBanner, isFalse);
  });

  test('openNotificationSettings invokes the injected callback', () async {
    await controller.openNotificationSettings();

    expect(openAppSettingsCalls, 1);
  });

  group('asking for notification permission', () {
    setUp(() async {
      controller.start();
    });

    test('Android: asks once, when the chat list first shows', () async {
      platform = 'android';
      // Android 13+ reports a permission nobody asked for as denied.
      answerPermission(_deniedNotificationSettings);
      await controller.handleAuthTokenChanged(authToken);
      verifyNever(() => mockPushMessagingService.requestPermission());

      await controller.requestPermissionIfUndecided();
      await controller.requestPermissionIfUndecided();

      verify(() => mockPushMessagingService.requestPermission()).called(1);
      verify(() => mockPushMessagingService.markPermissionRequested())
          .called(1);
    });

    test('Android: the banner shows only after a refusal', () async {
      platform = 'android';
      answerPermission(_deniedNotificationSettings);

      await controller.handleAuthTokenChanged(authToken);
      expect(controller.state.showNotificationsBanner, isFalse);

      await controller.requestPermissionIfUndecided();

      expect(controller.state.showNotificationsBanner, isTrue);
      expect(controller.state.canRequestPermissionAgain, isTrue);
    });

    test('Android: allowing keeps the banner away', () async {
      platform = 'android';
      answerPermission(_deniedNotificationSettings);
      when(() => mockPushMessagingService.requestPermission())
          .thenAnswer((_) async => _authorizedNotificationSettings);
      await controller.handleAuthTokenChanged(authToken);

      await controller.requestPermissionIfUndecided();

      expect(controller.state.showNotificationsBanner, isFalse);
    });

    test(
        'Android: refused before, then turned on in Settings: the banner '
        'goes on return', () async {
      platform = 'android';
      askedForPermission = true;
      answerPermission(_deniedNotificationSettings);
      await controller.handleAuthTokenChanged(authToken);
      await controller.requestPermissionIfUndecided();
      verifyNever(() => mockPushMessagingService.requestPermission());
      expect(controller.state.showNotificationsBanner, isTrue);

      answerPermission(_authorizedNotificationSettings);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(controller.state.showNotificationsBanner, isFalse);
    });

    test('iOS: asks while undecided, even with a flag from an old install',
        () async {
      // The Keychain keeps the flag across a reinstall; iOS doesn't keep the
      // answer.
      askedForPermission = true;
      answerPermission(_notDeterminedNotificationSettings);
      when(() => mockPushMessagingService.requestPermission())
          .thenAnswer((_) async => _authorizedNotificationSettings);
      await controller.handleAuthTokenChanged(authToken);

      await controller.requestPermissionIfUndecided();

      verify(() => mockPushMessagingService.requestPermission()).called(1);
      expect(controller.state.showNotificationsBanner, isFalse);
    });

    test('iOS: denied after asking: no prompt, the banner opens Settings',
        () async {
      askedForPermission = true;
      answerPermission(_deniedNotificationSettings);
      await controller.handleAuthTokenChanged(authToken);

      await controller.requestPermissionIfUndecided();

      verifyNever(() => mockPushMessagingService.requestPermission());
      expect(controller.state.showNotificationsBanner, isTrue);
      expect(controller.state.canRequestPermissionAgain, isFalse);
    });

    test('already allowed: asks nothing and records nothing', () async {
      await controller.handleAuthTokenChanged(authToken);

      await controller.requestPermissionIfUndecided();

      verifyNever(() => mockPushMessagingService.requestPermission());
      verifyNever(() => mockPushMessagingService.markPermissionRequested());
    });

    test('two calls at once ask once', () async {
      platform = 'android';
      answerPermission(_deniedNotificationSettings);
      final answer = Completer<NotificationSettings>();
      when(() => mockPushMessagingService.requestPermission())
          .thenAnswer((_) => answer.future);
      await controller.handleAuthTokenChanged(authToken);

      final first = controller.requestPermissionIfUndecided();
      final second = controller.requestPermissionIfUndecided();
      answer.complete(_deniedNotificationSettings);
      await Future.wait([first, second]);

      verify(() => mockPushMessagingService.requestPermission()).called(1);
    });

    test(
        'a request that fails is not recorded: the banner shows, and the next '
        'chat list asks again', () async {
      platform = 'android';
      answerPermission(_deniedNotificationSettings);
      when(() => mockPushMessagingService.requestPermission())
          .thenThrow(Exception('A request for permissions is already running'));
      await controller.handleAuthTokenChanged(authToken);

      await controller.requestPermissionIfUndecided();

      verifyNever(() => mockPushMessagingService.markPermissionRequested());
      expect(controller.state.showNotificationsBanner, isTrue);

      await controller.requestPermissionIfUndecided();
      verify(() => mockPushMessagingService.requestPermission()).called(2);
    });

    test('sign-in, returning to the app and new tokens never ask', () async {
      platform = 'android';
      answerPermission(_deniedNotificationSettings);

      await controller.handleAuthTokenChanged(authToken);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      tokenRefreshController.add('rotated-token');
      await pumpEventQueue();

      verifyNever(() => mockPushMessagingService.requestPermission());
      verifyNever(() => mockPushMessagingService.markPermissionRequested());
    });

    test('signed out: asks nothing', () async {
      platform = 'android';
      answerPermission(_deniedNotificationSettings);
      authToken = null;

      await controller.requestPermissionIfUndecided();

      verifyNever(() => mockPushMessagingService.requestPermission());
    });
  });

  group("the banner's button", () {
    setUp(() async {
      controller.start();
    });

    /// Signs in on [platform] and refuses the first permission prompt.
    Future<void> refuseFirstPrompt() async {
      answerPermission(_deniedNotificationSettings);
      await controller.handleAuthTokenChanged(authToken);
      await controller.requestPermissionIfUndecided();
      expect(controller.state.showNotificationsBanner, isTrue);
      clearInteractions(mockPushMessagingService);
    }

    test('Android: shows the system dialog once more, then opens Settings',
        () async {
      platform = 'android';
      await refuseFirstPrompt();
      when(() => mockPushMessagingService.requestPermission())
          .thenAnswer((_) async {
        // Read, then refused.
        clock = clock.add(const Duration(seconds: 2));
        return _deniedNotificationSettings;
      });

      await controller.turnOnNotifications();

      verify(() => mockPushMessagingService.requestPermission()).called(1);
      expect(openAppSettingsCalls, 0);
      expect(controller.state.showNotificationsBanner, isTrue);
      expect(controller.state.canRequestPermissionAgain, isFalse);

      await controller.turnOnNotifications();

      verifyNever(() => mockPushMessagingService.requestPermission());
      expect(openAppSettingsCalls, 1);
    });

    test('Android: opens Settings at once when Android shows no dialog',
        () async {
      platform = 'android';
      await refuseFirstPrompt();
      // Denied straight away: Android didn't show a dialog.

      await controller.turnOnNotifications();

      verify(() => mockPushMessagingService.requestPermission()).called(1);
      expect(openAppSettingsCalls, 1);
      expect(controller.state.canRequestPermissionAgain, isFalse);
    });

    test('Android: allowing in the dialog hides the banner', () async {
      platform = 'android';
      await refuseFirstPrompt();
      when(() => mockPushMessagingService.requestPermission())
          .thenAnswer((_) async {
        clock = clock.add(const Duration(seconds: 2));
        return _authorizedNotificationSettings;
      });

      await controller.turnOnNotifications();

      expect(controller.state.showNotificationsBanner, isFalse);
      expect(openAppSettingsCalls, 0);
    });

    test('iOS: opens Settings', () async {
      askedForPermission = true;
      await refuseFirstPrompt();

      await controller.turnOnNotifications();

      verifyNever(() => mockPushMessagingService.requestPermission());
      expect(openAppSettingsCalls, 1);
    });
  });

  group('deleting the FCM token after a sign-out', () {
    test(
        'a pending deletion is retried at launch, once the stored token is '
        'read, and on return, signed out', () async {
      // The app starts the controller before it has read the stored token.
      authToken = null;
      controller.start();
      await controller.handleAuthTokenChanged(authToken);
      verifyNever(() => mockPushMessagingService.retryPendingTokenDeletion());

      // None was stored. The provider retries once that's known.
      controller.handleConnectionRestored();
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

      verify(() => mockPushMessagingService.retryPendingTokenDeletion())
          .called(2);
    });

    test('a signed-in launch keeps the token, even with a deletion left over',
        () async {
      // Until the stored token is read, the launch looks signed out.
      authToken = null;
      controller.start();
      await controller.handleAuthTokenChanged(authToken);

      // The stored token is read, then the provider's launch retry runs.
      authToken = 'auth-token';
      await controller.handleAuthTokenChanged(authToken);
      controller.handleConnectionRestored();
      await pumpEventQueue();

      verifyNever(() => mockPushMessagingService.retryPendingTokenDeletion());
      verifyRegistered('push-token');
    });

    test('and when the connection comes back', () async {
      authToken = null;
      controller.start();
      clearInteractions(mockPushMessagingService);

      controller.handleConnectionRestored();

      verify(() => mockPushMessagingService.retryPendingTokenDeletion())
          .called(1);
    });

    test('is not retried while signed in', () async {
      controller.start();
      await controller.handleAuthTokenChanged(authToken);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      controller.handleConnectionRestored();
      await pumpEventQueue();

      verifyNever(() => mockPushMessagingService.retryPendingTokenDeletion());
    });

    test('a successful registration drops a pending deletion', () async {
      controller.start();

      await controller.handleAuthTokenChanged(authToken);

      verify(() => mockPushMessagingService.clearPendingTokenDeletion())
          .called(1);
    });

    test('a failed registration keeps it', () async {
      when(() => mockRegisterPushTokenUseCase(
            token: any(named: 'token'),
            platform: any(named: 'platform'),
            badge: any(named: 'badge'),
          )).thenThrow(Exception('offline'));
      controller.start();

      await controller.handleAuthTokenChanged(authToken);

      verifyNever(() => mockPushMessagingService.clearPendingTokenDeletion());
    });
  });

  group('the notification that launched the app', () {
    setUp(() {
      when(() => mockPushMessagingService.getInitialPayload())
          .thenAnswer((_) async => initialMessagePayload);
      when(() => mockGetRoomUseCase('room-1'))
          .thenAnswer((_) async => testRoom);
    });

    test('is not opened again after signing out and back in', () async {
      controller.start();
      await controller.handleAuthTokenChanged(authToken);
      await controller.markContentReady();
      expect(controller.state.navigationRequest, isNotNull);
      controller.consumeNavigation();

      await controller.handleAuthTokenChanged(null);
      authToken = 'next-session-token';
      await controller.handleAuthTokenChanged(authToken);
      await controller.markContentReady();

      expect(controller.state.navigationRequest, isNull);
      verify(() => mockPushMessagingService.getInitialPayload()).called(1);
      verify(() => mockGetRoomUseCase('room-1')).called(1);
    });

    test('opens while iOS has no APNs token yet', () async {
      when(() => mockPushMessagingService.getToken())
          .thenThrow(const ApnsTokenNotReadyException());
      controller.start();

      await controller.handleAuthTokenChanged(authToken);
      await controller.markContentReady();

      expect(
        controller.state.navigationRequest,
        isA<OpenRoomPushNavigationRequest>(),
      );
    });

    test('opens while the registration hangs', () async {
      when(() => mockRegisterPushTokenUseCase(
            token: any(named: 'token'),
            platform: any(named: 'platform'),
            badge: any(named: 'badge'),
          )).thenAnswer((_) => Completer<void>().future);
      controller.start();

      unawaited(controller.handleAuthTokenChanged(authToken));
      await pumpEventQueue();
      await controller.markContentReady();

      expect(
        controller.state.navigationRequest,
        isA<OpenRoomPushNavigationRequest>(),
      );
    });

    test('opens, and the token registers, when reading the permission fails',
        () async {
      when(() => mockPushMessagingService.getNotificationSettings())
          .thenThrow(Exception('unavailable'));
      controller.start();

      await controller.handleAuthTokenChanged(authToken);
      await controller.markContentReady();

      verifyRegistered('push-token');
      expect(
        controller.state.navigationRequest,
        isA<OpenRoomPushNavigationRequest>(),
      );
    });
  });

  group('registration while iOS has no APNs token', () {
    test('registers once the token arrives, on a short timer', () {
      fakeAsync((async) {
        var tokenReady = false;
        when(() => mockPushMessagingService.getToken()).thenAnswer((_) async {
          if (!tokenReady) throw const ApnsTokenNotReadyException();
          return 'push-token';
        });
        controller.start();

        controller.handleAuthTokenChanged(authToken);
        async.flushMicrotasks();
        tokenReady = true;
        async.elapse(const Duration(milliseconds: 1900));
        verifyNothingRegistered();

        async.elapse(const Duration(milliseconds: 100));
        verifyRegistered('push-token');

        async.elapse(const Duration(minutes: 3));
        verifyNoMoreInteractions(mockRegisterPushTokenUseCase);
      });
    });

    test('tries 5 more times over about a minute, then stops', () {
      fakeAsync((async) {
        when(() => mockPushMessagingService.getToken())
            .thenThrow(const ApnsTokenNotReadyException());
        controller.start();

        controller.handleAuthTokenChanged(authToken);
        async.elapse(const Duration(seconds: 61));
        verify(() => mockPushMessagingService.getToken()).called(5);

        async.elapse(const Duration(seconds: 1));
        verify(() => mockPushMessagingService.getToken()).called(1);

        async.elapse(const Duration(minutes: 10));
        verifyNever(() => mockPushMessagingService.getToken());
      });
    });

    test('a sign-out cancels the retry', () {
      fakeAsync((async) {
        when(() => mockPushMessagingService.getToken())
            .thenThrow(const ApnsTokenNotReadyException());
        controller.start();
        controller.handleAuthTokenChanged(authToken);
        async.flushMicrotasks();

        authToken = null;
        controller.handleAuthTokenChanged(null);
        async.elapse(const Duration(minutes: 3));

        verify(() => mockPushMessagingService.getToken()).called(1);
      });
    });

    test('closing the controller cancels the retry', () {
      fakeAsync((async) {
        when(() => mockPushMessagingService.getToken())
            .thenThrow(const ApnsTokenNotReadyException());
        final closing = createController()..start();
        closing.handleAuthTokenChanged(authToken);
        async.flushMicrotasks();

        closing.dispose();
        async.elapse(const Duration(minutes: 3));

        verify(() => mockPushMessagingService.getToken()).called(1);
      });
    });
  });
}
