import 'package:bleya/controllers/push_notifications_controller.dart';
import 'package:bleya/domain/entities/notification.dart';
import 'package:bleya/domain/repositories/notification_repository.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/pages/dashboard_page.dart';
import 'package:bleya/pages/notifications_page.dart';
import 'package:bleya/widgets/notification_tile.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/controller_providers.dart';
import 'package:bleya/providers/notification_provider.dart';
import 'package:bleya/providers/profile_providers.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:flutter/cupertino.dart' hide Notification;
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_socket_service.dart';
import '../mocks.dart';
import 'dashboard_page_test.dart'
    show
        TestNotificationSocketListenerNotifier,
        TestPushMessagingService,
        TestRegisterPushTokenUseCase,
        TestGetRoomUseCase,
        TestGetNotificationThreadContextUseCase,
        TestMarkNotificationAsReadUseCase;

Notification _reply(int i) => Notification(
      id: 'n$i',
      senderId: 'user-bob',
      senderName: 'bob',
      roomId: 'room-1',
      roomName: 'Belgrade',
      roomType: 'public',
      messageId: 'reply-$i',
      threadId: 'thread-1',
      replyText: 'Reply $i',
      previewText: 'Reply $i',
      type: 'reply',
      isRead: false,
      createdAt: DateTime(2026, 10, 1, 10),
    );

void main() {
  late MockRoomRepository rooms;
  late MockNotificationRepository notifications;

  setUp(() {
    rooms = MockRoomRepository();
    notifications = MockNotificationRepository();
    when(() => notifications.markAllAsRead()).thenAnswer((_) async {});
    when(() => notifications.fetchNotifications(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        )).thenAnswer((_) async => NotificationPage(
          notifications: [for (var i = 0; i < 20; i++) _reply(i)],
          unreadCount: 20,
        ));
    when(() => rooms.getJoinedRooms()).thenAnswer((_) async => [
          for (var i = 0; i < 40; i++)
            Room(
              id: 'room-$i',
              name: 'Room $i',
              lastMessageText: 'hi',
              lastMessageTime: DateTime(2026, 3, 14, 12, 0, 40 - i),
            ),
        ]);
  });

  ProviderScope app() => ProviderScope(
        overrides: [
          tokenProvider.overrideWith((ref) => 'test-token'),
          roomRepositoryProvider.overrideWithValue(rooms),
          notificationRepositoryProvider.overrideWithValue(notifications),
          socketServiceProvider.overrideWithValue(FakeSocketService()),
          notificationSocketListenerProvider
              .overrideWith(TestNotificationSocketListenerNotifier.new),
          // No profile: Settings shows its animated skeletons.
          profileProvider
              .overrideWith((ref) => ProfileController(ref, token: null)),
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
        child: const MaterialApp(home: DashboardPage()),
      );

  Future<void> tapTab(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  ScrollPosition chatListPosition(WidgetTester tester) {
    final scrollable = tester.state<ScrollableState>(find
        .descendant(
            of: find.byType(ListView, skipOffstage: false).first,
            matching: find.byType(Scrollable, skipOffstage: false))
        .first);
    return scrollable.position;
  }

  testWidgets('chat list keeps its scroll position across tab switches',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final before = chatListPosition(tester).pixels;
    expect(before, greaterThan(500));

    await tapTab(tester, CupertinoIcons.bell);
    await tapTab(tester, CupertinoIcons.gear);
    await tapTab(tester, CupertinoIcons.chat_bubble_2);

    expect(chatListPosition(tester).pixels, before);
  });

  testWidgets('Activity keeps its scroll position and its state',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapTab(tester, CupertinoIcons.bell);
    await tester.pumpAndSettle();
    final stateBefore =
        tester.state(find.byType(NotificationsPage, skipOffstage: false));

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(find
        .descendant(
            of: find.byType(NotificationsPage),
            matching: find.byType(Scrollable))
        .first);
    final before = scrollable.position.pixels;
    expect(before, greaterThan(200));

    await tapTab(tester, CupertinoIcons.chat_bubble_2);
    await tapTab(tester, CupertinoIcons.bell);

    expect(
        identical(
            tester.state(find.byType(NotificationsPage, skipOffstage: false)),
            stateBefore),
        isTrue);
    expect(scrollable.position.pixels, before);
  });

  testWidgets('leaving Activity marks all read; Chats<->Settings does not',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(DashboardPage)));

    await tapTab(tester, CupertinoIcons.gear);
    await tapTab(tester, CupertinoIcons.chat_bubble_2);
    verifyNever(() => notifications.markAllAsRead());
    expect(
        container.read(notificationStateProvider).requireValue.unreadCount, 20);

    await tapTab(tester, CupertinoIcons.bell);
    verifyNever(() => notifications.markAllAsRead());
    await tapTab(tester, CupertinoIcons.chat_bubble_2);

    verify(() => notifications.markAllAsRead()).called(1);
    final state = container.read(notificationStateProvider).requireValue;
    expect(state.unreadCount, 0);
    expect(state.notifications, hasLength(20));
  });

  testWidgets('a hidden tab\'s skeleton animations are paused', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tapTab(tester, CupertinoIcons.gear);
    // Settings skeletons animate while visible.
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tapTab(tester, CupertinoIcons.chat_bubble_2);
    // Would time out if the hidden Settings skeletons kept ticking.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('re-tapping the active tab scrolls it to the top',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(chatListPosition(tester).pixels, greaterThan(500));

    // Selected Chats icon is the filled one.
    await tester.tap(find.byIcon(CupertinoIcons.chat_bubble_2_fill));
    await tester.pumpAndSettle();
    expect(chatListPosition(tester).pixels, 0);
  });

  testWidgets('the Scaffold primary controller only drives the visible tab',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapTab(tester, CupertinoIcons.gear);
    await tapTab(tester, CupertinoIcons.chat_bubble_2);

    final scaffoldContext = tester.element(find.byType(Scaffold).first);
    final primary = PrimaryScrollController.of(scaffoldContext);
    expect(primary.positions, hasLength(1));
  });

  testWidgets('chat list scrolled to the very bottom keeps its position',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final pos = chatListPosition(tester);
    pos.jumpTo(pos.maxScrollExtent);
    await tester.pumpAndSettle();
    final before = pos.pixels;

    await tapTab(tester, CupertinoIcons.bell);
    await tester.pumpAndSettle();
    await tapTab(tester, CupertinoIcons.chat_bubble_2);
    await tester.pumpAndSettle();
    expect(chatListPosition(tester).pixels, before);
  });

  testWidgets('Activity shows current times when the tab shows again',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapTab(tester, CupertinoIcons.bell);
    await tester.pumpAndSettle();
    await tapTab(tester, CupertinoIcons.chat_bubble_2);
    await tester.pumpAndSettle();

    var tileBuilds = 0;
    debugOnRebuildDirtyWidget = (e, _) {
      if (e.widget is NotificationTile) tileBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    await tapTab(tester, CupertinoIcons.bell);
    await tester.pumpAndSettle();
    expect(tileBuilds, greaterThan(0));
  });
}
