import 'package:bleya/domain/entities/notification.dart';
import 'package:bleya/domain/repositories/notification_repository.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/chat_providers.dart';
import 'package:bleya/providers/notification_provider.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_io_socket.dart';
import '../mocks.dart';

final _reply = Notification(
  id: 'n1',
  senderId: 'carol-id',
  senderName: 'carol',
  roomId: 'room-x',
  roomName: 'Belgrade',
  roomType: 'public',
  messageId: 'reply-1',
  threadId: 'thread-1',
  previewText: 'See you there',
  type: 'reply',
  isRead: false,
  createdAt: DateTime(2026, 10, 1, 9),
);

/// The chat list and Activity on the real socket service, with the test
/// playing the server and the network.
void main() {
  late List<FakeIoSocket> sockets;
  late SocketService service;
  late MockRoomRepository rooms;
  late MockNotificationRepository notifications;
  late ProviderContainer container;
  late bool online;

  setUp(() {
    online = true;
    sockets = [];
    service = SocketService(socketFactory: (url, options) {
      final socket = FakeIoSocket(options);
      sockets.add(socket);
      return socket;
    });
    service.setToken('token-1');
    rooms = MockRoomRepository();
    notifications = MockNotificationRepository();
    when(() => rooms.getJoinedRooms()).thenAnswer((_) async {
      if (!online) throw Exception('offline');
      return [Room(id: 'room-x', name: 'Belgrade', hasUnreadCount: true)];
    });
    when(
      () => notifications.fetchNotifications(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer((_) async {
      if (!online) throw Exception('offline');
      return NotificationPage(notifications: [_reply], unreadCount: 1);
    });
    container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => 'token-1'),
        socketServiceProvider.overrideWithValue(service),
        roomRepositoryProvider.overrideWithValue(rooms),
        notificationRepositoryProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
    // Signing out also stops the service's timers.
    addTearDown(service.disconnect);
  });

  FakeIoSocket socket() => sockets.last;

  /// Shows the dashboard: the chat list, and Activity with its live listener.
  Future<void> showDashboard() async {
    container.listen(roomsListProvider, (_, __) {});
    container.listen(notificationStateProvider, (_, __) {});
    container.listen(notificationSocketListenerProvider, (_, __) {});
    await pumpEventQueue();
  }

  void verifyEachListFetched(int times) {
    verify(() => rooms.getJoinedRooms()).called(times);
    verify(
      () => notifications.fetchNotifications(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).called(times);
  }

  test(
      'a chat list and Activity that failed to load offline load on the '
      'first connect', () async {
    online = false;
    await showDashboard();
    // No network: the connection attempt fails, and so do both loads.
    socket().failConnection();
    await pumpEventQueue();
    expect(container.read(roomsListProvider).hasError, isTrue);
    expect(container.read(notificationStateProvider).hasError, isTrue);

    // The network is back, and socket.io's own retry gets through.
    online = true;
    socket().acceptConnection();
    await pumpEventQueue();

    expect(
      container.read(roomsListProvider).requireValue.map((i) => i.room.id),
      ['room-x'],
    );
    expect(
      container
          .read(notificationStateProvider)
          .requireValue
          .notifications
          .map((n) => n.id),
      ['n1'],
    );
  });

  test('one return to the foreground fetches each list once more', () async {
    await showDashboard();
    socket().acceptConnection();
    await pumpEventQueue();
    verifyEachListFetched(1);

    service.setForeground(false);
    service.setForeground(true);
    await pumpEventQueue();
    socket().acceptConnection();
    await pumpEventQueue();

    verifyEachListFetched(1);
  });

  test('a first connect after a good start fetches nothing more', () async {
    await showDashboard();
    socket().acceptConnection();
    await pumpEventQueue();

    verifyEachListFetched(1);
  });
}
