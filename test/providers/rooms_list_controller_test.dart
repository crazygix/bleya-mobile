import 'dart:async';
import 'dart:convert';

import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/chat_providers.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_socket_service.dart';
import '../mocks.dart';

/// An access token for the signed-in user, `me`.
final _myToken = () {
  String encode(Map<String, Object> part) =>
      base64Url.encode(utf8.encode(jsonEncode(part))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode({'userId': 'me'})}.sig';
}();

final _monday = DateTime(2026, 10, 5, 9);

/// [minutes] after nine on Monday morning.
DateTime _at(int minutes) => _monday.add(Duration(minutes: minutes));

/// A room as `GET /rooms/joined` returns it, with the server's unread count.
Room _room(
  String id, {
  int unread = 0,
  DateTime? at,
  String text = 'Morning!',
  String from = 'bob',
}) {
  return Room(
    id: id,
    name: 'Room $id',
    lastMessageText: text,
    lastMessageTime: at ?? _monday,
    lastMessageUserId: from,
    lastMessageUsername: from,
    unreadCount: unread,
    hasUnreadCount: true,
  );
}

/// A message_removed event for a message [from] sent [at] in [roomId], as
/// the server sends it to the chat lists.
Map<String, dynamic> _removal(
  String roomId,
  DateTime at, {
  String from = 'bob',
  String? parentMessageId,
}) {
  return {
    'messageId': 'message-${at.millisecondsSinceEpoch}',
    'roomId': roomId,
    'parentMessageId': parentMessageId,
    'userId': from,
    'createdAt': at.millisecondsSinceEpoch,
  };
}

/// A room_summary_updated event for a new message in [roomId].
Map<String, dynamic> _summary(
  String roomId,
  DateTime at, {
  String text = 'Still there?',
  String from = 'bob',
}) {
  return {
    'roomId': roomId,
    'lastMessageText': text,
    'lastMessageTime': at.millisecondsSinceEpoch,
    'lastMessageUserId': from,
    'lastMessageUsername': from,
  };
}

void main() {
  late MockRoomRepository rooms;
  late MockMessageRepository messages;
  late FakeSocketService socket;
  late ProviderContainer container;
  late List<String> readPosts;

  setUp(() {
    rooms = MockRoomRepository();
    messages = MockMessageRepository();
    socket = FakeSocketService();
    readPosts = [];
    when(() => messages.markRoomAsRead(any())).thenAnswer((invocation) async {
      readPosts.add(invocation.positionalArguments.single as String);
      return 0;
    });
    container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => _myToken),
        socketServiceProvider.overrideWithValue(socket),
        roomRepositoryProvider.overrideWithValue(rooms),
        messageRepositoryProvider.overrideWithValue(messages),
      ],
    );
    addTearDown(container.dispose);
    // Ends the claims a test made, and their timers.
    addTearDown(socket.disconnect);
  });

  void answerRooms(Future<List<Room>> Function() answer) {
    when(() => rooms.getJoinedRooms()).thenAnswer((_) => answer());
  }

  /// Shows the chat list, as the dashboard does.
  Future<void> showList() async {
    container.listen(roomsListProvider, (_, __) {});
    await pumpEventQueue();
  }

  RoomsListController controller() =>
      container.read(roomsListProvider.notifier);

  List<RoomListItem> items() => container.read(roomsListProvider).requireValue;

  RoomListItem item(String roomId) =>
      items().singleWhere((item) => item.room.id == roomId);

  Map<String, int> unreadByRoom() => {
        for (final item in items()) item.room.id: item.unreadCount,
      };

  /// Opens [roomId] as a chat screen does.
  Future<void> openChat(String roomId) async {
    socket.claimRoom(_room(roomId));
    await pumpEventQueue();
  }

  test('refreshes when the socket asks it to catch up', () async {
    answerRooms(() async => [_room('room-d', unread: 1)]);
    await showList();

    answerRooms(() async => [_room('room-d', unread: 4, at: _at(5))]);
    socket.requestResync();
    await pumpEventQueue();

    expect(unreadByRoom(), {'room-d': 4});
    verify(() => rooms.getJoinedRooms()).called(2);
  });

  test("takes the server's unread counts, with 0 for the open room", () async {
    answerRooms(
      () async => [_room('room-x', unread: 3), _room('room-d', unread: 2)],
    );
    await openChat('room-x');
    await showList();
    expect(unreadByRoom(), {'room-x': 0, 'room-d': 2});

    // Two messages arrive in the DM, then the list is fetched again: the
    // server's count wins over what the app counted.
    socket.emit('room_summary_updated', _summary('room-d', _at(1)));
    socket.emit('room_summary_updated', _summary('room-d', _at(2)));
    expect(item('room-d').unreadCount, 4);

    answerRooms(
      () async => [
        _room('room-x', unread: 5, at: _at(3)),
        _room('room-d', unread: 1, at: _at(2)),
      ],
    );
    await controller().refresh();

    expect(unreadByRoom(), {'room-x': 0, 'room-d': 1});
  });

  test('keeps summaries that arrive during a fetch and applies them after it',
      () async {
    answerRooms(() async => [_room('room-d', text: 'Hi')]);
    await showList();

    final page = Completer<List<Room>>();
    answerRooms(() => page.future);
    final refreshing = controller().refresh();
    await pumpEventQueue();

    // Bob writes while the list loads, and the server answered before that.
    socket.emit('room_summary_updated', _summary('room-d', _at(2)));
    expect(item('room-d').room.lastMessageText, 'Still there?');
    page.complete([_room('room-d', text: 'Hi')]);
    await refreshing;

    expect(item('room-d').room.lastMessageText, 'Still there?');
    expect(item('room-d').room.lastMessageTime, _at(2));
    expect(item('room-d').unreadCount, 1);
  });

  test('ignores summaries that are not newer than what is shown', () async {
    answerRooms(() async => [_room('room-d', text: 'Hi')]);
    await showList();

    final page = Completer<List<Room>>();
    answerRooms(() => page.future);
    final refreshing = controller().refresh();
    await pumpEventQueue();

    // The server's answer already counts this message.
    socket.emit('room_summary_updated', _summary('room-d', _at(2)));
    page.complete(
      [_room('room-d', unread: 1, at: _at(2), text: 'Still there?')],
    );
    await refreshing;
    expect(item('room-d').unreadCount, 1);

    // A late summary for an older message changes nothing.
    socket.emit(
      'room_summary_updated',
      _summary('room-d', _at(1), text: 'Old news'),
    );

    expect(item('room-d').room.lastMessageText, 'Still there?');
    expect(item('room-d').unreadCount, 1);
  });

  test('runs overlapping refreshes once more instead of dropping them',
      () async {
    answerRooms(() async => [_room('room-d')]);
    await showList();
    clearInteractions(rooms);

    final first = Completer<List<Room>>();
    answerRooms(() => first.future);
    final refreshes = [controller().refresh()];
    await pumpEventQueue();
    // A chat that is new on the server by the time the next fetch runs.
    answerRooms(() async => [_room('room-n', at: _at(1)), _room('room-d')]);
    refreshes
      ..add(controller().refresh())
      ..add(controller().refresh());
    await pumpEventQueue();
    verify(() => rooms.getJoinedRooms()).called(1);

    first.complete([_room('room-d')]);
    await Future.wait(refreshes);

    verify(() => rooms.getJoinedRooms()).called(1);
    expect(items().map((item) => item.room.id), ['room-n', 'room-d']);
  });

  test("a new chat's first message shows it, also while a fetch runs",
      () async {
    answerRooms(() async => [_room('room-x')]);
    await showList();

    final page = Completer<List<Room>>();
    answerRooms(() => page.future);
    final refreshing = controller().refresh();
    await pumpEventQueue();

    // Ana starts a chat while the list loads; the answer on its way is older.
    socket.emit(
      'room_summary_updated',
      _summary('room-ana', _at(2), from: 'ana', text: 'Hey!'),
    );
    answerRooms(
      () async => [_room('room-ana', unread: 1, at: _at(2)), _room('room-x')],
    );
    page.complete([_room('room-x')]);
    await refreshing;

    expect(unreadByRoom(), {'room-ana': 1, 'room-x': 0});
  });

  test('marks a room read on the server even while the list loads', () async {
    final page = Completer<List<Room>>();
    answerRooms(() => page.future);
    container.listen(roomsListProvider, (_, __) {});
    await pumpEventQueue();
    expect(container.read(roomsListProvider).isLoading, isTrue);

    controller().markRoomAsRead('room-d');
    expect(readPosts, ['room-d']);

    // The server counted before it saw the read; the list shows it read.
    page.complete([_room('room-d', unread: 3), _room('room-x', unread: 2)]);
    await pumpEventQueue();

    expect(unreadByRoom(), {'room-d': 0, 'room-x': 2});
  });

  test('counts only messages that arrive after a room was marked read',
      () async {
    answerRooms(() async => [_room('room-d', unread: 1)]);
    await showList();

    final page = Completer<List<Room>>();
    answerRooms(() => page.future);
    final refreshing = controller().refresh();
    await pumpEventQueue();
    socket.emit('room_summary_updated', _summary('room-d', _at(1)));
    controller().markRoomAsRead('room-d');
    socket.emit('room_summary_updated', _summary('room-d', _at(2)));
    expect(item('room-d').unreadCount, 1);

    page.complete([_room('room-d', unread: 2)]);
    await refreshing;

    expect(item('room-d').unreadCount, 1);
    expect(readPosts, ['room-d']);
  });

  test('a refresh that fails keeps the list', () async {
    answerRooms(() async => [_room('room-d', unread: 2)]);
    await showList();

    answerRooms(() async => throw Exception('offline'));
    await controller().refresh();

    expect(unreadByRoom(), {'room-d': 2});
    expect(socket.resyncOnConnectRequests, 0);
  });

  test(
      'a first load that fails shows the error and loads again when the '
      'socket asks', () async {
    answerRooms(() async => throw Exception('offline'));
    await showList();

    expect(container.read(roomsListProvider).hasError, isTrue);
    expect(socket.resyncOnConnectRequests, 1);

    answerRooms(() async => [_room('room-d')]);
    socket.requestResync();
    await pumpEventQueue();

    expect(items().map((item) => item.room.id), ['room-d']);
  });

  group('moderator removals', () {
    /// Runs [body] with timers under its control, the chat list showing.
    void withList(void Function(FakeAsync async) body) {
      fakeAsync((async) {
        container.listen(roomsListProvider, (_, __) {});
        async.flushMicrotasks();
        clearInteractions(rooms);
        body(async);
      });
    }

    test(
        'removing previews loads the list once, half a second after the last '
        'removal', () {
      answerRooms(
        () async => [
          _room('room-d', at: _at(3), text: 'Spam'),
          _room('room-x', at: _at(2), text: 'Spam', from: 'eve'),
        ],
      );
      withList((async) {
        answerRooms(
          () async => [
            _room('room-x', at: _at(1), text: 'Hello'),
            _room('room-d', at: _at(0), text: 'Morning!'),
          ],
        );
        // One moderator action removes three messages.
        socket.emit('message_removed', _removal('room-d', _at(3)));
        async.elapse(const Duration(milliseconds: 300));
        socket.emit('message_removed', _removal('room-d', _at(1)));
        socket.emit(
          'message_removed',
          _removal('room-x', _at(2), from: 'eve'),
        );
        async.elapse(const Duration(milliseconds: 499));
        verifyNever(() => rooms.getJoinedRooms());

        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();

        verify(() => rooms.getJoinedRooms()).called(1);
        expect(item('room-x').room.lastMessageText, 'Hello');
        expect(item('room-d').room.lastMessageText, 'Morning!');
      });
    });

    test('a removed reply, an older message or another room loads nothing', () {
      answerRooms(() async => [_room('room-d', at: _at(3))]);
      withList((async) {
        socket.emit(
          'message_removed',
          _removal('room-d', _at(3), parentMessageId: 'message-1'),
        );
        socket.emit('message_removed', _removal('room-d', _at(2)));
        socket.emit('message_removed', _removal('room-d', _at(3), from: 'eve'));
        socket.emit('message_removed', _removal('room-q', _at(3)));
        async.elapse(const Duration(seconds: 2));

        verifyNever(() => rooms.getJoinedRooms());
      });
    });

    test("without the message's author and time, a listed room loads again",
        () {
      answerRooms(() async => [_room('room-d', at: _at(3))]);
      withList((async) {
        socket.emit('message_removed', {
          'messageId': 'message-9',
          'roomId': 'room-d',
          'parentMessageId': null,
        });
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        verify(() => rooms.getJoinedRooms()).called(1);
      });
    });

    test('a removal while the list loads loads it again afterwards', () {
      answerRooms(() async => [_room('room-d', at: _at(3))]);
      withList((async) {
        final page = Completer<List<Room>>();
        answerRooms(() => page.future);
        controller().refresh();
        async.flushMicrotasks();

        // The answer on its way may still show the removed message.
        socket.emit('message_removed', _removal('room-n', _at(4)));
        page.complete(
          [_room('room-n', at: _at(4), text: 'Spam'), _room('room-d')],
        );
        async.flushMicrotasks();
        answerRooms(() async => [_room('room-d', at: _at(3))]);
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        verify(() => rooms.getJoinedRooms()).called(2);
        expect(items().map((item) => item.room.id), ['room-d']);
      });
    });

    test('listens once, and stops when the list goes', () {
      answerRooms(() async => [_room('room-d')]);
      withList((async) {
        controller().refresh();
        async.flushMicrotasks();

        expect(socket.listenerCount('message_removed'), 1);
        expect(socket.listenerCount('room_summary_updated'), 1);

        // A removal waits to load the list when the session ends.
        socket.emit('message_removed', _removal('room-d', _monday));
        container.read(tokenProvider.notifier).state = null;
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));

        expect(socket.listenerCount('message_removed'), 0);
        expect(socket.listenerCount('room_summary_updated'), 0);
        verify(() => rooms.getJoinedRooms()).called(1);
      });
    });
  });
}
