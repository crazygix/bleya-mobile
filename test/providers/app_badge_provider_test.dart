import 'dart:async';
import 'dart:convert';

import 'package:bleya/domain/repositories/notification_repository.dart';
import 'package:bleya/providers/app_badge_provider.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/chat_providers.dart';
import 'package:bleya/providers/notification_provider.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/app_lifecycle.dart';
import '../fakes/fake_app_badge_service.dart';
import '../fakes/fake_socket_service.dart';
import '../mocks.dart';

/// An access token for the signed-in user, `me`.
final _myToken = () {
  String encode(Map<String, Object> part) =>
      base64Url.encode(utf8.encode(jsonEncode(part))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode({'userId': 'me'})}.sig';
}();

final _monday = DateTime(2026, 10, 5, 9);

/// A chat as `GET /rooms/joined` returns it, with the server's unread count.
Room _chat(String id, {String type = 'public', int unread = 0}) {
  return Room(
    id: id,
    name: 'Chat $id',
    type: type,
    lastMessageText: 'Morning!',
    lastMessageTime: _monday,
    lastMessageUserId: 'bob',
    lastMessageUsername: 'bob',
    unreadCount: unread,
    hasUnreadCount: true,
  );
}

Room _cityRoom(String id, {int unread = 0}) => _chat(id, unread: unread);

Room _dm(String id, {int unread = 0}) =>
    _chat(id, type: 'private', unread: unread);

/// A first page of Activity with [unread] unread items.
NotificationPage _activity({required int unread}) {
  return NotificationPage(notifications: const [], unreadCount: unread);
}

void main() {
  late MockRoomRepository rooms;
  late MockMessageRepository messages;
  late MockNotificationRepository notifications;
  late FakeSocketService socket;
  late FakeAppBadgeService badge;

  setUp(() {
    rooms = MockRoomRepository();
    messages = MockMessageRepository();
    notifications = MockNotificationRepository();
    socket = FakeSocketService();
    badge = FakeAppBadgeService();
    when(() => messages.markRoomAsRead(any())).thenAnswer((_) async => 0);
    when(() => notifications.markAllAsRead()).thenAnswer((_) async {});
  });

  void answerRooms(Future<List<Room>> Function() answer) {
    when(() => rooms.getJoinedRooms()).thenAnswer((_) => answer());
  }

  void answerActivity(Future<NotificationPage> Function() answer) {
    when(
      () => notifications.fetchNotifications(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer((_) => answer());
  }

  /// Lets loads finish and the providers that follow them catch up.
  Future<void> settle(WidgetTester tester) {
    return tester.pump(const Duration(milliseconds: 10));
  }

  /// The app's providers, with the dashboard keeping the badge current.
  Future<ProviderContainer> showDashboard(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => _myToken),
        socketServiceProvider.overrideWithValue(socket),
        roomRepositoryProvider.overrideWithValue(rooms),
        messageRepositoryProvider.overrideWithValue(messages),
        notificationRepositoryProvider.overrideWithValue(notifications),
        appBadgeServiceProvider.overrideWithValue(badge),
      ],
    );
    addTearDown(container.dispose);
    container.listen(appBadgeProvider, (_, __) {});
    await settle(tester);
    return container;
  }

  testWidgets(
      'counts unread Activity items and DMs with unread messages, not city '
      'rooms', (tester) async {
    answerRooms(() async => [
          _cityRoom('belgrade', unread: 7),
          _dm('dm-ana', unread: 2),
          _dm('dm-bob'),
          _dm('dm-eva', unread: 1),
        ]);
    answerActivity(() async => _activity(unread: 3));

    await showDashboard(tester);

    expect(badge.counts, [5]);
  });

  testWidgets('follows the chat list and Activity as they change',
      (tester) async {
    answerRooms(() async => [_cityRoom('belgrade'), _dm('dm-ana')]);
    answerActivity(() async => _activity(unread: 1));
    final container = await showDashboard(tester);

    // A new DM, a message in the city room, then the DM is read.
    socket.emit('room_summary_updated', {
      'roomId': 'dm-ana',
      'lastMessageText': 'Coffee?',
      'lastMessageTime':
          _monday.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      'lastMessageUserId': 'ana',
      'lastMessageUsername': 'ana',
    });
    await settle(tester);
    socket.emit('room_summary_updated', {
      'roomId': 'belgrade',
      'lastMessageText': 'Anyone around?',
      'lastMessageTime':
          _monday.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
      'lastMessageUserId': 'bob',
      'lastMessageUsername': 'bob',
    });
    await settle(tester);
    container.read(roomsListProvider.notifier).markRoomAsRead('dm-ana');
    await settle(tester);
    // Everything in Activity is read.
    await container.read(notificationStateProvider.notifier).markAllAsRead();
    await settle(tester);

    expect(badge.counts, [1, 2, 1, 0]);
  });

  testWidgets('shows nothing until both lists have loaded', (tester) async {
    final roomsPage = Completer<List<Room>>();
    answerRooms(() => roomsPage.future);
    answerActivity(() async => _activity(unread: 2));

    await showDashboard(tester);
    expect(badge.counts, isEmpty);

    roomsPage.complete([_dm('dm-ana', unread: 4)]);
    await settle(tester);

    expect(badge.counts, [3]);
  });

  testWidgets('goes to 0 at sign-out', (tester) async {
    answerRooms(() async => [_dm('dm-ana', unread: 1)]);
    answerActivity(() async => _activity(unread: 2));
    final container = await showDashboard(tester);

    container.read(tokenProvider.notifier).state = null;
    await settle(tester);

    expect(badge.counts, [3, 0]);
  });

  testWidgets('sets the badge again when the app returns to the foreground',
      (tester) async {
    await setAppLifecycleState(tester, AppLifecycleState.resumed);
    answerRooms(() async => [_dm('dm-ana', unread: 1)]);
    answerActivity(() async => _activity(unread: 1));
    await showDashboard(tester);

    // Pushes may have changed the badge while the app was away.
    await setAppLifecycleState(tester, AppLifecycleState.paused);
    await setAppLifecycleState(tester, AppLifecycleState.resumed);

    expect(badge.counts, [2, 2]);
  });

  testWidgets('does nothing on Android', (tester) async {
    badge = FakeAppBadgeService(isSupported: false);
    answerRooms(() async => [_dm('dm-ana', unread: 1)]);
    answerActivity(() async => _activity(unread: 1));

    await showDashboard(tester);
    await setAppLifecycleState(tester, AppLifecycleState.paused);
    await setAppLifecycleState(tester, AppLifecycleState.resumed);

    expect(badge.counts, isEmpty);
    verifyNever(() => rooms.getJoinedRooms());
  });
}
