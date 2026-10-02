import 'package:bleya/domain/entities/notification.dart';
import 'package:bleya/domain/repositories/notification_repository.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/block_providers.dart';
import 'package:bleya/providers/chat_providers.dart';
import 'package:bleya/providers/notification_provider.dart';
import 'package:bleya/providers/profile_providers.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:flutter/widgets.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_socket_service.dart';
import '../mocks.dart';

Notification _reply(String id, String senderId) {
  return Notification(
    id: id,
    senderId: senderId,
    senderName: senderId,
    roomId: 'room-1',
    roomName: 'Belgrade',
    roomType: 'public',
    messageId: 'reply-$id',
    threadId: 'thread-1',
    previewText: 'See you there',
    type: 'reply',
    isRead: false,
    createdAt: DateTime(2026, 10, 1),
  );
}

const _chatStatus = DirectChatStatus(
  hasChat: true,
  roomId: 'room-d',
  isBlockedByMe: false,
  isBlockedByOtherUser: false,
  canSendMessage: true,
  isDeletedByMe: false,
);

void main() {
  late MockRoomRepository rooms;
  late MockUserRepository users;
  late MockNotificationRepository notifications;
  late ProviderContainer container;
  late WidgetRef ref;

  setUp(() {
    rooms = MockRoomRepository();
    users = MockUserRepository();
    notifications = MockNotificationRepository();
    when(() => rooms.getJoinedRooms())
        .thenAnswer((_) async => [Room(id: 'room-1', name: 'Belgrade')]);
    when(() => rooms.getDirectChatStatus(any()))
        .thenAnswer((_) async => _chatStatus);
    when(() => users.getBlockedUsers()).thenAnswer((_) async => []);
    container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => 'test-token'),
        socketServiceProvider.overrideWithValue(FakeSocketService()),
        roomRepositoryProvider.overrideWithValue(rooms),
        userRepositoryProvider.overrideWithValue(users),
        notificationRepositoryProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
  });

  void answerActivity(List<Notification> items) {
    when(
      () => notifications.fetchNotifications(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer(
      (_) async => NotificationPage(
        notifications: items,
        unreadCount: items.length,
      ),
    );
  }

  /// The dashboard, with a profile of carol open on top of it.
  Future<void> showProfile(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    container.listen(roomsListProvider, (_, __) {});
    container.listen(notificationStateProvider, (_, __) {});
    container.listen(blockedUsersProvider, (_, __) {});
    container.listen(directChatStatusProvider('carol'), (_, __) {});
    await tester.pump();
    clearInteractions(rooms);
    clearInteractions(users);
    clearInteractions(notifications);
  }

  List<String> activityIds() => container
      .read(notificationStateProvider)
      .requireValue
      .notifications
      .map((n) => n.id)
      .toList();

  testWidgets('a block hides the user everywhere at once, then reloads',
      (tester) async {
    answerActivity([_reply('n1', 'carol'), _reply('n2', 'dan')]);
    await showProfile(tester);

    answerActivity([_reply('n2', 'dan')]);
    recordBlockChange(ref, 'carol', blocked: true);

    expect(container.read(sessionBlockedUserIdsProvider), {'carol'});
    expect(activityIds(), ['n2']);
    expect(
      container.read(notificationStateProvider).requireValue.unreadCount,
      1,
    );

    await tester.pump();
    verify(() => rooms.getJoinedRooms()).called(1);
    verify(() => rooms.getDirectChatStatus('carol')).called(1);
    verify(() => users.getBlockedUsers()).called(1);
    verify(
      () => notifications.fetchNotifications(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).called(1);
  });

  testWidgets('an unblock shows the user again and brings back their items',
      (tester) async {
    answerActivity([_reply('n2', 'dan')]);
    await showProfile(tester);
    container.read(sessionBlockedUserIdsProvider.notifier).state = {'carol'};

    answerActivity([_reply('n1', 'carol'), _reply('n2', 'dan')]);
    recordBlockChange(ref, 'carol', blocked: false);
    await tester.pump();

    expect(container.read(sessionBlockedUserIdsProvider), isEmpty);
    expect(activityIds(), ['n1', 'n2']);
    verify(() => rooms.getJoinedRooms()).called(1);
    verify(() => users.getBlockedUsers()).called(1);
  });
}
