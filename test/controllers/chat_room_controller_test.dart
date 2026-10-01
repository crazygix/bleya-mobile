import 'dart:async';

import 'package:bleya/domain/entities/message.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/domain/repositories/message_repository.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/chat_room_providers.dart';
import 'package:bleya/providers/use_case_providers.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:bleya/use_cases/message/get_room_messages_page_use_case.dart';
import 'package:bleya/use_cases/message/get_thread_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_socket_service.dart';

class MockGetThreadUseCase extends Mock implements GetThreadUseCase {}

class MockGetRoomMessagesPageUseCase extends Mock
    implements GetRoomMessagesPageUseCase {}

SendMessageResult _failed(String code, String message) {
  return SendMessageResult.failed(
      SocketErrorData(code: code, message: message));
}

Message _message(
  String id, {
  String userId = 'user-2',
  int replyCount = 0,
  DateTime? createdAt,
  String? parentMessageId,
}) {
  return Message(
    id: id,
    roomId: 'room-1',
    userId: userId,
    username: 'bob',
    text: 'hi',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    parentMessageId: parentMessageId,
    replyCount: replyCount,
  );
}

/// A message [minutes] after the start of the day, with an id that sorts the
/// same way.
Message _at(int minutes, {String? id}) {
  return _message(
    id ?? 'm${minutes.toString().padLeft(3, '0')}',
    createdAt: DateTime(2026, 1, 1).add(Duration(minutes: minutes)),
  );
}

/// A message as the socket sends it.
Map<String, dynamic> _payload(Message message) {
  return {
    'id': message.id,
    'roomId': message.roomId,
    'userId': message.userId,
    'username': message.username,
    'text': message.text,
    'createdAt': message.createdAt.millisecondsSinceEpoch,
    'parentMessageId': message.parentMessageId,
    'replyCount': message.replyCount,
  };
}

Map<String, dynamic> _roomJoined(
  List<Message> messages, {
  bool hasMore = false,
  String? nextCursor,
}) {
  return {
    'room': {'id': 'room-1', 'name': 'General'},
    'messages': messages.map(_payload).toList(),
    'pagination': {'hasMore': hasMore, 'nextCursor': nextCursor},
    'lastReadAt': null,
  };
}

RoomMessagesPage _page(
  List<Message> messages, {
  bool hasMore = true,
  String? nextCursor,
}) {
  return RoomMessagesPage(
    messages: messages,
    hasMore: hasMore,
    nextCursor: nextCursor,
  );
}

List<String> _ids(Iterable<Message> messages) =>
    messages.map((message) => message.id).toList();

void main() {
  final room = Room(id: 'room-1', name: 'General');

  late FakeSocketService socket;
  late ProviderContainer container;
  late List<ProviderSubscription<Object?>> subscriptions;

  setUp(() {
    socket = FakeSocketService();
    subscriptions = [];
    container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => 'token'),
        socketServiceProvider.overrideWithValue(socket),
      ],
    );
  });

  tearDown(() async {
    // Let auto-disposed controllers dispose while the container is alive,
    // as they do when the app closes a screen.
    for (final subscription in subscriptions) {
      subscription.close();
    }
    await pumpEventQueue();
    container.dispose();
    socket.disconnect();
  });

  // Keeps an auto-disposed provider alive, as a watching screen does.
  void keepAlive(ProviderListenable<Object?> provider) {
    subscriptions.add(container.listen(provider, (_, __) {}));
  }

  group('ChatRoomController', () {
    setUp(() {
      keepAlive(chatRoomControllerProvider(room));
      keepAlive(roomMessagesProvider(room.id));
    });

    ChatRoomController controller() =>
        container.read(chatRoomControllerProvider(room).notifier);
    ChatRoomState chatState() =>
        container.read(chatRoomControllerProvider(room));
    List<Message> messages() => container.read(roomMessagesProvider(room.id));

    /// Puts this room's screen on top, as opening the chat does.
    Future<void> openRoom() async {
      socket.claimRoom(room);
      await pumpEventQueue();
    }

    test(
        'returns why a rejected message was not stored, without a '
        'duplicate toast from the error event', () async {
      await openRoom();
      final toasts = <String>[];
      controller().errorMessages.listen(toasts.add);
      socket.sendResults.add(
        _failed('BAD_REQUEST', 'Message contains blocked content.'),
      );

      final result = await controller().sendMessage('bad words');
      await pumpEventQueue();

      expect(result.isSent, isFalse);
      expect(result.error?.message, 'Message contains blocked content.');
      expect(toasts, isEmpty);
    });

    test('sends to its own room and leaves the retry to the socket', () async {
      await openRoom();
      final toasts = <String>[];
      controller().errorMessages.listen(toasts.add);
      socket.sendResults.add(
        _failed(SocketService.notInRoomCode, 'Not in a room.'),
      );

      final result = await controller().sendMessage('hello');
      await pumpEventQueue();

      expect(result.error?.code, SocketService.notInRoomCode);
      expect(socket.sentTexts, ['hello']);
      expect(socket.sentRoomIds, ['room-1']);
      expect(toasts, isEmpty);
    });

    test('still shows an unrelated error that arrives during a send', () async {
      await openRoom();
      final toasts = <String>[];
      controller().errorMessages.listen(toasts.add);
      socket.sendResults.add(const SendMessageResult.sent(null));
      socket.duringSend = () => socket.emit('error', {
            'error': {
              'code': 'TOO_MANY_REQUESTS',
              'message': 'Too many join requests. Please slow down.',
            },
          });

      await controller().sendMessage('hello');
      await pumpEventQueue();

      expect(toasts, ['Too many join requests. Please slow down.']);
    });

    test('a NOT_IN_ROOM error event shows nothing and asks for no join',
        () async {
      await openRoom();
      final toasts = <String>[];
      controller().errorMessages.listen(toasts.add);

      socket.emit('error', {
        'error': {'code': 'NOT_IN_ROOM', 'message': 'Reopen the chat.'},
      });
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(toasts, isEmpty);
      expect(socket.snapshotRequests, isEmpty);
      expect(socket.retriedJoins, isEmpty);
    });

    test('shows socket errors only while its room is the open chat', () async {
      final toasts = <String>[];
      controller().errorMessages.listen(toasts.add);
      const error = {
        'error': {
          'code': 'FORBIDDEN',
          'message': 'That reply belongs to a different chat.',
        },
      };

      socket.emit('error', error);
      await pumpEventQueue();
      expect(toasts, isEmpty);

      await openRoom();
      socket.emit('error', error);
      await pumpEventQueue();
      expect(toasts, ['That reply belongs to a different chat.']);

      // Another chat opened on top.
      socket.claimRoom(Room(id: 'room-2', name: 'ana', type: 'private'));
      await pumpEventQueue();
      socket.emit('error', error);
      await pumpEventQueue();
      expect(toasts, hasLength(1));
    });

    test('loads the room from room_joined', () async {
      controller();
      expect(chatState().isInitialLoading, isTrue);

      socket.emit(
        'room_joined',
        _roomJoined([_at(1), _at(2)], hasMore: true, nextCursor: 'cursor-1'),
      );

      expect(_ids(messages()), ['m001', 'm002']);
      expect(chatState().isInitialLoading, isFalse);
      expect(chatState().hasMore, isTrue);
      expect(chatState().nextCursor, 'cursor-1');
    });

    test('a room_joined after a reconnect keeps the older messages loaded',
        () async {
      controller();
      container.read(roomMessagesProvider(room.id).notifier).state = [
        for (var minute = 1; minute <= 6; minute++) _at(minute),
      ];
      container.read(chatRoomControllerProvider(room).notifier).state =
          chatState().copyWith(
        isInitialLoading: false,
        hasMore: true,
        nextCursor: 'older-cursor',
      );

      // The newest page overlaps what's loaded; m005 was removed meanwhile.
      socket.emit(
        'room_joined',
        _roomJoined(
          [_at(4), _at(6), _at(7)],
          hasMore: true,
          nextCursor: 'page-cursor',
        ),
      );

      expect(
          _ids(messages()), ['m001', 'm002', 'm003', 'm004', 'm006', 'm007']);
      expect(chatState().hasMore, isTrue);
      expect(chatState().nextCursor, 'older-cursor');
    });

    test('a room_joined for this room that cannot be read shows the error',
        () async {
      controller();

      socket.emit('room_joined', {
        'room': {'id': 'room-1', 'name': 'General'},
        'messages': [
          {'id': 'broken'},
        ],
      });

      expect(chatState().isInitialLoading, isFalse);
      expect(chatState().joinError, isNotNull);
    });

    test('ignores a new_message already listed', () async {
      controller();
      socket.emit('room_joined', _roomJoined([_at(1)]));

      socket.emit('new_message', _payload(_at(2)));
      socket.emit('new_message', _payload(_at(2)));
      socket.emit('new_message', _payload(_at(1)));

      expect(_ids(messages()), ['m001', 'm002']);
    });

    test(
        'a join failure sets joinError, and retryJoin clears it and tries '
        'again', () async {
      controller();

      socket.failJoin(
        room.id,
        const SocketErrorData(
          code: SocketService.joinTimeoutCode,
          message: 'Check your connection and try again.',
        ),
      );

      expect(chatState().joinError, 'Check your connection and try again.');
      expect(chatState().isInitialLoading, isFalse);

      controller().retryJoin();

      expect(chatState().joinError, isNull);
      expect(chatState().isInitialLoading, isTrue);
      expect(socket.retriedJoins, ['room-1']);

      socket.emit('room_joined', _roomJoined([_at(1)]));
      expect(chatState().joinError, isNull);
      expect(_ids(messages()), ['m001']);
    });

    test('ignores join failures of other rooms', () async {
      controller();

      socket.failJoin(
        'room-2',
        const SocketErrorData(code: 'FORBIDDEN', message: 'Not allowed.'),
      );

      expect(chatState().joinError, isNull);
      expect(chatState().isInitialLoading, isTrue);
    });

    test('a refusal while messages are on screen shows a toast', () async {
      await openRoom();
      final toasts = <String>[];
      controller().errorMessages.listen(toasts.add);
      socket.emit('room_joined', _roomJoined([_at(1)]));

      socket.failJoin(
        room.id,
        const SocketErrorData(
          code: SocketService.joinTimeoutCode,
          message: 'Check your connection and try again.',
        ),
      );
      socket.failJoin(
        room.id,
        const SocketErrorData(
          code: 'FORBIDDEN',
          message: 'You are not allowed to join this chat.',
        ),
      );
      await pumpEventQueue();

      expect(toasts, ['You are not allowed to join this chat.']);
    });

    test('ensureLoaded asks for the room only while it is loading', () async {
      controller().ensureLoaded();
      expect(socket.snapshotRequests, ['room-1']);

      socket.emit('room_joined', _roomJoined([_at(1)]));
      controller().ensureLoaded();

      expect(socket.snapshotRequests, ['room-1']);
    });

    test('removing a reply lowers its parent reply count', () async {
      controller();
      container.read(roomMessagesProvider(room.id).notifier).state = [
        _message('parent-1', replyCount: 2),
      ];

      socket.emit('message_removed', {
        'messageId': 'reply-1',
        'roomId': room.id,
        'parentMessageId': 'parent-1',
      });

      expect(
        container.read(roomMessagesProvider(room.id)).single.replyCount,
        1,
      );
    });
  });

  group('ChatRoomController paging', () {
    late MockGetRoomMessagesPageUseCase olderPages;

    setUp(() {
      olderPages = MockGetRoomMessagesPageUseCase();
      container.dispose();
      container = ProviderContainer(
        overrides: [
          tokenProvider.overrideWith((ref) => 'token'),
          socketServiceProvider.overrideWithValue(socket),
          getRoomMessagesPageUseCaseProvider.overrideWithValue(olderPages),
        ],
      );
      keepAlive(chatRoomControllerProvider(room));
      keepAlive(roomMessagesProvider(room.id));
      socket.emit(
        'room_joined',
        _roomJoined([_at(3), _at(4)], hasMore: true, nextCursor: 'cursor-3'),
      );
    });

    ChatRoomController controller() =>
        container.read(chatRoomControllerProvider(room).notifier);
    ChatRoomState chatState() =>
        container.read(chatRoomControllerProvider(room));
    List<Message> messages() => container.read(roomMessagesProvider(room.id));

    test('older messages keep loading from where the list ends after a rejoin',
        () async {
      when(() => olderPages('room-1', before: 'cursor-3', limit: null))
          .thenAnswer((_) async => _page([_at(1), _at(2)], hasMore: false));

      // The socket comes back while older messages load.
      final loading = controller().loadOlderMessages();
      socket.emit(
        'room_joined',
        _roomJoined([_at(4), _at(5)], hasMore: true, nextCursor: 'cursor-4'),
      );
      await loading;

      expect(_ids(messages()), ['m001', 'm002', 'm003', 'm004', 'm005']);
      expect(chatState().hasMore, isFalse);
    });

    test('drops older messages that arrive after a rejoin replaced the list',
        () async {
      when(() => olderPages('room-1', before: 'cursor-3', limit: null))
          .thenAnswer((_) async => _page([_at(1), _at(2)]));

      // Many messages were missed: the new page doesn't reach the list.
      final loading = controller().loadOlderMessages();
      socket.emit(
        'room_joined',
        _roomJoined(
          [_at(60), _at(61)],
          hasMore: true,
          nextCursor: 'cursor-60',
        ),
      );
      await loading;

      expect(_ids(messages()), ['m060', 'm061']);
      expect(chatState().isLoadingMore, isFalse);
      expect(chatState().nextCursor, 'cursor-60');
    });
  });

  group('mergeLatestPage', () {
    test('keeps older messages and their cursor where the page overlaps', () {
      final merged = mergeLatestPage(
        _page([_at(1), _at(2), _at(3), _at(4)], nextCursor: 'older'),
        _page([_at(3), _at(4), _at(5)], nextCursor: 'page'),
      );

      expect(_ids(merged.messages), ['m001', 'm002', 'm003', 'm004', 'm005']);
      expect(merged.hasMore, isTrue);
      expect(merged.nextCursor, 'older');
    });

    test('replaces the list when there may be a gap before the page', () {
      final merged = mergeLatestPage(
        _page([_at(1), _at(2)], nextCursor: 'older'),
        _page([_at(5), _at(6)], nextCursor: 'page'),
      );

      expect(_ids(merged.messages), ['m005', 'm006']);
      expect(merged.nextCursor, 'page');
    });

    test('drops a message removed inside the page window', () {
      final merged = mergeLatestPage(
        _page([_at(1), _at(2), _at(3), _at(4)]),
        _page([_at(2), _at(4)]),
      );

      expect(_ids(merged.messages), ['m001', 'm002', 'm004']);
    });

    test('orders messages with the same time by id, as the server does', () {
      final sameTime = DateTime(2026, 1, 1, 12);
      Message at(String id) => _message(id, createdAt: sameTime);

      final merged = mergeLatestPage(
        _page([at('a1'), at('a2'), at('a3')]),
        _page([at('a2'), at('a4')]),
      );

      // a1 sorts before the page; a3 is inside it but missing, so it's gone.
      expect(_ids(merged.messages), ['a1', 'a2', 'a4']);
    });

    test('takes the page when it is the whole room', () {
      final merged = mergeLatestPage(
        _page([_at(1), _at(2), _at(3)], nextCursor: 'older'),
        _page([_at(2), _at(3)], hasMore: false),
      );

      expect(_ids(merged.messages), ['m002', 'm003']);
      expect(merged.hasMore, isFalse);
      expect(merged.nextCursor, isNull);
    });

    test('takes the page when nothing is loaded, and an empty page empties',
        () {
      expect(
        _ids(mergeLatestPage(_page([]), _page([_at(1)])).messages),
        ['m001'],
      );
      expect(
        mergeLatestPage(_page([_at(1)]), _page([], hasMore: false)).messages,
        isEmpty,
      );
    });

    test('takes the page cursor when the page covers everything loaded', () {
      final merged = mergeLatestPage(
        _page([_at(3), _at(4)], nextCursor: 'older'),
        _page([_at(2), _at(3), _at(4)], nextCursor: 'page'),
      );

      expect(_ids(merged.messages), ['m002', 'm003', 'm004']);
      expect(merged.nextCursor, 'page');
    });
  });

  group('ThreadController', () {
    late MockGetThreadUseCase getThread;

    Message reply(String id) => _message(id, parentMessageId: 'parent-1');

    ThreadData thread(List<String> replyIds) => ThreadData(
          parentMessage: _message('parent-1'),
          replies: replyIds.map(reply).toList(),
        );

    setUp(() {
      getThread = MockGetThreadUseCase();
      when(() => getThread('parent-1'))
          .thenAnswer((_) async => thread(['reply-1', 'reply-2']));
      container.dispose();
      container = ProviderContainer(
        overrides: [
          tokenProvider.overrideWith((ref) => 'token'),
          socketServiceProvider.overrideWithValue(socket),
          getThreadUseCaseProvider.overrideWithValue(getThread),
        ],
      );
    });

    // Opens the thread, as its screen does: the controller starts fetching.
    void showThread() => keepAlive(threadMessagesProvider('parent-1'));

    List<String> replyIds() =>
        _ids(container.read(threadMessagesProvider('parent-1')).value!.replies);

    test('flags the thread for closing when its parent is removed', () async {
      keepAlive(threadParentRemovedProvider('parent-1'));
      showThread();
      await pumpEventQueue();

      socket.emit('message_removed', {
        'messageId': 'parent-1',
        'roomId': room.id,
        'parentMessageId': null,
      });

      expect(container.read(threadParentRemovedProvider('parent-1')), isTrue);
    });

    test('still closes after a retry recreated the controller', () async {
      keepAlive(threadParentRemovedProvider('parent-1'));
      showThread();
      await pumpEventQueue();

      container.invalidate(threadMessagesProvider('parent-1'));
      container.read(threadMessagesProvider('parent-1').notifier);
      await pumpEventQueue();
      socket.emit('message_removed', {
        'messageId': 'parent-1',
        'roomId': room.id,
        'parentMessageId': null,
      });

      expect(container.read(threadParentRemovedProvider('parent-1')), isTrue);
    });

    test('drops a removed reply', () async {
      showThread();
      await pumpEventQueue();

      socket.emit('message_removed', {
        'messageId': 'reply-1',
        'roomId': room.id,
        'parentMessageId': 'parent-1',
      });

      expect(replyIds(), ['reply-2']);
    });

    test('a reply sent during the first fetch appears once', () async {
      final firstFetch = Completer<ThreadData>();
      when(() => getThread('parent-1')).thenAnswer((_) => firstFetch.future);
      showThread();

      socket.emit('new_message', _payload(reply('reply-2')));
      socket.emit('new_message', _payload(reply('reply-3')));
      firstFetch.complete(thread(['reply-1', 'reply-2']));
      await pumpEventQueue();

      expect(replyIds(), ['reply-1', 'reply-2', 'reply-3']);
    });

    test('fetches again when its room is joined again, keeping live replies',
        () async {
      showThread();
      await pumpEventQueue();

      final refetch = Completer<ThreadData>();
      when(() => getThread('parent-1')).thenAnswer((_) => refetch.future);
      socket.emit('room_joined', _roomJoined(const []));
      socket.emit('new_message', _payload(reply('reply-4')));
      // reply-2 was removed while the socket was away; reply-3 was missed.
      refetch.complete(thread(['reply-1', 'reply-3']));
      await pumpEventQueue();

      expect(replyIds(), ['reply-1', 'reply-3', 'reply-4']);
      verify(() => getThread('parent-1')).called(2);
    });

    test('ignores room_joined for other rooms', () async {
      showThread();
      await pumpEventQueue();

      socket.emit('room_joined', {
        'room': {'id': 'room-2', 'name': 'Novi Sad'},
        'messages': const [],
        'pagination': {'hasMore': false},
      });
      await pumpEventQueue();

      verify(() => getThread('parent-1')).called(1);
    });

    test('fetches once more when its room was joined during the first fetch',
        () async {
      final firstFetch = Completer<ThreadData>();
      when(() => getThread('parent-1')).thenAnswer((_) => firstFetch.future);
      showThread();

      socket.emit('room_joined', _roomJoined(const []));
      when(() => getThread('parent-1'))
          .thenAnswer((_) async => thread(['reply-1', 'reply-2', 'reply-3']));
      firstFetch.complete(thread(['reply-1', 'reply-2']));
      await pumpEventQueue();

      expect(replyIds(), ['reply-1', 'reply-2', 'reply-3']);
    });

    test('a failed fetch after a rejoin keeps the replies', () async {
      showThread();
      await pumpEventQueue();

      when(() => getThread('parent-1')).thenThrow(Exception('offline'));
      socket.emit('room_joined', _roomJoined(const []));
      await pumpEventQueue();

      expect(
          container.read(threadMessagesProvider('parent-1')).hasError, isFalse);
      expect(replyIds(), ['reply-1', 'reply-2']);
    });
  });

  group('blocking during a session', () {
    test('hides the blocked user messages until unblocked', () {
      final messages = [
        _message('m1', userId: 'user-2'),
        _message('m2', userId: 'user-3'),
      ];

      expect(
        withoutBlockedAuthors(messages, {'user-2'}).map((m) => m.id),
        ['m2'],
      );
      expect(withoutBlockedAuthors(messages, const {}), messages);
    });

    test('the blocked set resets when the user signs out', () {
      container.read(sessionBlockedUserIdsProvider.notifier).state = {
        'user-2',
      };

      container.read(tokenProvider.notifier).state = null;

      expect(container.read(sessionBlockedUserIdsProvider), isEmpty);
    });
  });
}
