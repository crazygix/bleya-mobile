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
import 'package:firebase_messaging/firebase_messaging.dart';
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

const _authorizedNotificationSettings = NotificationSettings(
  authorizationStatus: AuthorizationStatus.authorized,
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

const _deniedNotificationSettings = NotificationSettings(
  authorizationStatus: AuthorizationStatus.denied,
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

    when(() => mockPushMessagingService.getNotificationSettings())
        .thenAnswer((_) async => _authorizedNotificationSettings);
    when(() => mockPushMessagingService.getToken())
        .thenAnswer((_) async => 'push-token');
    when(() => mockPushMessagingService.getInitialPayload())
        .thenAnswer((_) async => null);
    when(() => mockPushMessagingService.onTokenRefresh)
        .thenAnswer((_) => tokenRefreshController.stream);
    when(() => mockPushMessagingService.onMessageOpenedApp)
        .thenAnswer((_) => messageOpenedController.stream);

    when(() => mockRegisterPushTokenUseCase(
          token: any(named: 'token'),
          platform: any(named: 'platform'),
        )).thenAnswer((_) async {});

    controller = PushNotificationsController(
      mockPushMessagingService,
      mockRegisterPushTokenUseCase,
      mockGetRoomUseCase,
      mockGetNotificationThreadContextUseCase,
      mockMarkNotificationAsReadUseCase,
      () => authToken,
      supportsPushPlatform: () => true,
      platformName: () => 'ios',
    );
  });

  tearDown(() async {
    controller.dispose();
    await tokenRefreshController.close();
    await messageOpenedController.close();
  });

  test('waits for content readiness before navigating initial push', () async {
    when(() => mockPushMessagingService.getInitialPayload())
        .thenAnswer((_) async => initialMessagePayload);
    when(() => mockGetRoomUseCase('room-1')).thenAnswer((_) async => testRoom);

    controller.start();
    await controller.handleAuthTokenChanged(authToken);

    expect(controller.state.navigationRequest, isNull);
    verify(() => mockRegisterPushTokenUseCase(
          token: 'push-token',
          platform: 'ios',
        )).called(1);

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

    verify(() => mockRegisterPushTokenUseCase(
          token: 'rotated-token',
          platform: 'ios',
        )).called(1);
  });

  test('registers token even when notification permission is denied', () async {
    // The FCM token is valid without notification permission (notably on
    // Android), so registration must not be gated on the authorization status;
    // otherwise the backend never gets a deliverable token for that device.
    when(() => mockPushMessagingService.getNotificationSettings())
        .thenAnswer((_) async => _deniedNotificationSettings);

    controller.start();
    await controller.handleAuthTokenChanged(authToken);

    verify(() => mockRegisterPushTokenUseCase(
          token: 'push-token',
          platform: 'ios',
        )).called(1);
  });

  test('skips registration when no FCM token is available', () async {
    when(() => mockPushMessagingService.getToken())
        .thenAnswer((_) async => null);

    controller.start();
    await controller.handleAuthTokenChanged(authToken);

    verifyNever(() => mockRegisterPushTokenUseCase(
          token: any(named: 'token'),
          platform: any(named: 'platform'),
        ));
  });
}
