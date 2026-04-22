import 'dart:async';

import 'package:bleya/controllers/push_notifications_controller.dart';
import 'package:bleya/domain/entities/push_notification_payload.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/pages/dashboard_page.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/controller_providers.dart';
import 'package:bleya/providers/notification_provider.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:bleya/services/push_messaging_service.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:bleya/use_cases/notification/get_notification_thread_context_use_case.dart';
import 'package:bleya/use_cases/notification/mark_notification_as_read_use_case.dart';
import 'package:bleya/use_cases/notification/register_push_token_use_case.dart';
import 'package:bleya/use_cases/room/get_room_use_case.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks.dart';

class TestNotificationSocketListenerNotifier
    extends NotificationSocketListenerNotifier {
  @override
  Future<void> build() async {}
}

class TestNotificationNotifier extends NotificationNotifier {
  @override
  FutureOr<NotificationState> build() {
    return const NotificationState(
      notifications: [],
      unreadCount: 0,
      hasMore: false,
    );
  }
}

class TestPushMessagingService extends Fake implements PushMessagingService {
  @override
  Future<NotificationSettings> getNotificationSettings() async =>
      _authorizedNotificationSettings;

  @override
  Future<NotificationSettings> requestPermission() async =>
      _authorizedNotificationSettings;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<PushNotificationPayload> get onMessageOpenedApp =>
      const Stream.empty();

  @override
  Future<PushNotificationPayload?> getInitialPayload() async => null;
}

class TestRegisterPushTokenUseCase extends Fake
    implements RegisterPushTokenUseCase {}

class TestGetRoomUseCase extends Fake implements GetRoomUseCase {}

class TestGetNotificationThreadContextUseCase extends Fake
    implements GetNotificationThreadContextUseCase {}

class TestMarkNotificationAsReadUseCase extends Fake
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

void main() {
  late MockRoomRepository mockRoomRepository;

  setUp(() {
    mockRoomRepository = MockRoomRepository();
  });

  ProviderScope buildApp() {
    return ProviderScope(
      overrides: [
        tokenProvider.overrideWith((ref) => 'test-token'),
        roomRepositoryProvider.overrideWithValue(mockRoomRepository),
        socketServiceProvider.overrideWithValue(SocketService()),
        notificationStateProvider.overrideWith(TestNotificationNotifier.new),
        notificationSocketListenerProvider
            .overrideWith(TestNotificationSocketListenerNotifier.new),
        pushNotificationsControllerProvider.overrideWith((ref) {
          return PushNotificationsController(
            TestPushMessagingService(),
            TestRegisterPushTokenUseCase(),
            TestGetRoomUseCase(),
            TestGetNotificationThreadContextUseCase(),
            TestMarkNotificationAsReadUseCase(),
            () => 'test-token',
            supportsPushPlatform: () => false,
            platformName: () => 'ios',
          );
        }),
      ],
      child: const MaterialApp(
        home: DashboardPage(),
      ),
    );
  }

  Room room({
    required String id,
    required String name,
    String? lastMessageText,
    DateTime? lastMessageTime,
  }) {
    return Room(
      id: id,
      name: name,
      lastMessageText: lastMessageText,
      lastMessageTime: lastMessageTime,
    );
  }

  testWidgets(
      'retry button refreshes the dashboard after an initial load error',
      (tester) async {
    var callCount = 0;
    when(() => mockRoomRepository.getJoinedRooms()).thenAnswer((_) async {
      callCount += 1;
      if (callCount == 1) {
        throw Exception('network');
      }

      return [
        room(
          id: 'room-1',
          name: 'Belgrade crew',
          lastMessageText: 'See you there',
          lastMessageTime: DateTime(2026, 3, 14, 12),
        ),
      ];
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your chats"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Belgrade crew'), findsOneWidget);
    verify(() => mockRoomRepository.getJoinedRooms()).called(2);
  });

  testWidgets('pull to refresh works even when the chat list is short',
      (tester) async {
    when(() => mockRoomRepository.getJoinedRooms()).thenAnswer((_) async => [
          room(
            id: 'room-1',
            name: 'Belgrade crew',
            lastMessageText: 'See you there',
            lastMessageTime: DateTime(2026, 3, 14, 12),
          ),
        ]);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Belgrade crew'), findsOneWidget);
    verify(() => mockRoomRepository.getJoinedRooms()).called(1);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    verify(() => mockRoomRepository.getJoinedRooms()).called(1);
  });
}
