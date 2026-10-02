import 'dart:async';

import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_io_socket.dart';

final _roomX = Room(id: 'room-x', name: 'Belgrade');
final _roomY = Room(id: 'room-y', name: 'Novi Sad');
final _dm = Room(id: 'room-d', name: 'ana', type: 'private');

const _notInRoomEvent = {
  'error': {
    'code': 'NOT_IN_ROOM',
    'message': 'Not in a room. Reopen the chat and try again.',
  },
};

const _tokenExpiredEvent = {
  'error': {
    'code': 'TOKEN_EXPIRED',
    'message': 'Authentication error: session expired',
  },
};

/// A room_joined event as the server sends it.
Map<String, dynamic> _roomJoined(Room room) {
  return {
    'room': {'id': room.id, 'name': room.name, 'type': room.type},
    'messages': const [],
    'pagination': {'hasMore': false, 'nextCursor': null},
    'lastReadAt': null,
  };
}

/// A signed-in [SocketService] on fake sockets; the test plays the server.
class _Harness {
  _Harness(this.async) {
    service = SocketService(socketFactory: (url, options) {
      final socket = FakeIoSocket(options);
      sockets.add(socket);
      return socket;
    });
    service.refreshToken = () async {
      refreshCalls++;
      return refreshedToken;
    };
    service.onFatalError = (message) async => fatalMessages.add(message);
    service.joinFailures.listen(failures.add);
    service.resyncRequests.listen((_) => resyncs++);
    service.setToken('token-1');
  }

  final FakeAsync async;
  late final SocketService service;
  final List<FakeIoSocket> sockets = [];
  final List<RoomJoinFailure> failures = [];
  final List<String> fatalMessages = [];
  int refreshCalls = 0;
  String? refreshedToken = 'token-2';

  /// How often the lists were asked to catch up.
  int resyncs = 0;

  FakeIoSocket get socket => sockets.last;

  /// Runs what the service scheduled for after the current change.
  void settle() => async.flushMicrotasks();

  /// The server accepts the pending connection.
  void connect() {
    socket.acceptConnection();
    settle();
  }

  /// The server confirms the join of [room].
  void joined(Room room) {
    socket.serverEmit('room_joined', _roomJoined(room));
    settle();
  }

  /// Claims [room] (and [threadId]), connects if needed, and confirms the
  /// join.
  RoomClaim openChat(Room room, {String? threadId}) {
    final claim = service.claimRoom(room, threadId: threadId);
    settle();
    if (!socket.connected) {
      connect();
    }
    joined(room);
    return claim;
  }

  /// Sends [text] to [room]; the result is filled in once the send ends.
  List<SendMessageResult> send(String text, Room room) {
    final results = <SendMessageResult>[];
    service.sendMessage(text, room: room).then(results.add);
    settle();
    return results;
  }
}

void _runFake(void Function(_Harness harness) body) {
  fakeAsync((async) {
    final harness = _Harness(async);
    body(harness);
    harness.service.disconnect();
    async.flushMicrotasks();
  });
}

void main() {
  group('SocketConnectionError.tryParse', () {
    test('reads a ban from a handshake rejection without the map braces', () {
      final error = SocketConnectionError.tryParse(
        {'message': 'Account blocked: Spamming other users.'},
      );

      expect(error?.kind, SocketConnectionErrorKind.accountBlocked);
      expect(error?.message, 'Spamming other users.');
    });

    test('falls back to a default ban message when the reason is empty', () {
      final error = SocketConnectionError.tryParse(
        {'message': 'Account blocked:'},
      );

      expect(error?.kind, SocketConnectionErrorKind.accountBlocked);
      expect(error?.message, SocketConnectionError.defaultBlockedMessage);
    });

    test('treats handshake auth errors as refreshable', () {
      final error = SocketConnectionError.tryParse(
        {'message': 'Authentication error: Invalid token', 'data': null},
      );

      expect(error?.kind, SocketConnectionErrorKind.authentication);
    });

    test('treats the mid-session TOKEN_EXPIRED event as refreshable', () {
      final error = SocketConnectionError.tryParse({
        'error': {
          'code': 'TOKEN_EXPIRED',
          'message': 'Authentication error: session expired',
        },
      });

      expect(error?.kind, SocketConnectionErrorKind.authentication);
    });

    test('treats a server outage as temporary', () {
      final error = SocketConnectionError.tryParse(
        {'message': 'Server unavailable: please try again shortly.'},
      );

      expect(error?.kind, SocketConnectionErrorKind.serverUnavailable);
    });

    test('accepts a plain string payload', () {
      final error =
          SocketConnectionError.tryParse('Authentication error: No token');

      expect(error?.kind, SocketConnectionErrorKind.authentication);
    });

    test('leaves errors about a single event to the screens', () {
      expect(
        SocketConnectionError.tryParse({
          'error': {
            'code': 'BAD_REQUEST',
            'message': 'Message contains blocked content.',
          },
        }),
        isNull,
      );
      expect(
        SocketConnectionError.tryParse({
          'error': {'code': 'NOT_IN_ROOM', 'message': 'Not in a room.'},
        }),
        isNull,
      );
      expect(SocketConnectionError.tryParse(null), isNull);
    });
  });

  group('SocketService.parseSendMessageAck', () {
    final service = SocketService();

    test('returns the stored message when the server accepted it', () {
      final result = service.parseSendMessageAck({
        'ok': true,
        'message': {
          'id': 'm1',
          'roomId': 'r1',
          'userId': 'u1',
          'username': 'alice',
          'text': 'hello',
          'createdAt': 1700000000000,
        },
      });

      expect(result.isSent, isTrue);
      expect(result.message?.id, 'm1');
    });

    test('returns the code and message when the server rejected it', () {
      final result = service.parseSendMessageAck({
        'ok': false,
        'error': {'code': 'NOT_IN_ROOM', 'message': 'Not in a room.'},
      });

      expect(result.isSent, isFalse);
      expect(result.error?.code, 'NOT_IN_ROOM');
      expect(result.error?.message, 'Not in a room.');
    });

    test('unwraps an acknowledgement delivered as a list', () {
      final result = service.parseSendMessageAck([
        {'ok': true},
      ]);

      expect(result.isSent, isTrue);
    });

    test('treats a missing or malformed acknowledgement as a failure', () {
      expect(service.parseSendMessageAck(null).isSent, isFalse);
      expect(service.parseSendMessageAck('ok').isSent, isFalse);
    });
  });

  group('SocketService.parseMessageRemovedPayload', () {
    final service = SocketService();

    test('reads a removal with its author and time', () {
      final removal = service.parseMessageRemovedPayload({
        'messageId': 'm1',
        'roomId': 'r1',
        'parentMessageId': 'p1',
        'userId': 'u1',
        'createdAt': 1700000000000,
      })!;

      expect(removal.messageId, 'm1');
      expect(removal.roomId, 'r1');
      expect(removal.parentMessageId, 'p1');
      expect(removal.userId, 'u1');
      expect(
        removal.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('reads a top-level removal from an older backend', () {
      final removal = service.parseMessageRemovedPayload({
        'messageId': 'm1',
        'roomId': 'r1',
        'parentMessageId': null,
      })!;

      expect(removal.parentMessageId, isNull);
      expect(removal.userId, isNull);
      expect(removal.createdAt, isNull);
    });

    test('ignores a payload without a message or room', () {
      expect(service.parseMessageRemovedPayload({'roomId': 'r1'}), isNull);
      expect(
        service.parseMessageRemovedPayload({'messageId': 'm1', 'roomId': ''}),
        isNull,
      );
    });
  });

  group('SocketService.sendMessage', () {
    test('fails right away instead of dropping the text when offline',
        () async {
      final result = await SocketService().sendMessage(
        'hello',
        room: Room(id: 'room-x', name: 'Belgrade'),
      );

      expect(result.isSent, isFalse);
      expect(result.error?.code, SocketService.notConnectedCode);
    });
  });

  group('SocketService connection errors', () {
    late SocketService service;
    late int refreshCalls;
    late List<String> fatalMessages;

    setUp(() {
      service = SocketService();
      refreshCalls = 0;
      fatalMessages = [];
      service.refreshToken = () async {
        refreshCalls++;
        return 'fresh-token';
      };
      service.onFatalError = (message) async {
        fatalMessages.add(message);
      };
    });

    tearDown(() {
      service.disconnect();
    });

    test('signs out with the ban reason and does not refresh', () async {
      service.handleSocketErrorForTesting(
        {'message': 'Account blocked: Spamming other users.'},
      );
      await pumpEventQueue();

      expect(fatalMessages, ['Spamming other users.']);
      expect(refreshCalls, 0);
    });

    test('refreshes the token on an auth rejection', () async {
      service.handleSocketErrorForTesting(
        {'message': 'Authentication error: Invalid token'},
      );
      await pumpEventQueue();

      expect(refreshCalls, 1);
      expect(fatalMessages, isEmpty);
    });

    test('backs off instead of refreshing again when the new token is rejected',
        () async {
      service.handleSocketErrorForTesting(
        {'message': 'Authentication error: Invalid token'},
      );
      await pumpEventQueue();
      service.handleSocketErrorForTesting(
        {'message': 'Authentication error: Invalid token'},
      );
      await pumpEventQueue();

      expect(refreshCalls, 1);
    });

    test('neither refreshes nor signs out during a server outage', () async {
      service.handleSocketErrorForTesting(
        {'message': 'Server unavailable: please try again shortly.'},
      );
      await pumpEventQueue();

      expect(refreshCalls, 0);
      expect(fatalMessages, isEmpty);
    });

    test('ignores errors about a single event', () async {
      service.handleSocketErrorForTesting({
        'error': {'code': 'BAD_REQUEST', 'message': 'Blocked content.'},
      });
      await pumpEventQueue();

      expect(refreshCalls, 0);
      expect(fatalMessages, isEmpty);
    });
  });

  group('SocketService rooms', () {
    test(
        'a claim over a claim joins the top one, and releasing it rejoins '
        'the one below', () {
      _runFake((h) {
        h.service.claimRoom(_roomX);
        h.settle();
        expect(h.socket.connectCalls, 1);
        expect(h.socket.sent, isEmpty);

        h.connect();
        expect(h.socket.joinRequests, ['room-x']);
        h.joined(_roomX);

        final dm = h.openChat(_dm);
        expect(h.socket.joinRequests, ['room-x', 'room-d']);

        h.service.releaseClaim(dm);
        h.settle();

        expect(h.socket.joinRequests, ['room-x', 'room-d', 'room-x']);
        expect(h.socket.sentEvents, isNot(contains('leave_room')));
      });
    });

    test('two claims on the same room emit nothing extra', () {
      _runFake((h) {
        h.service.claimRoom(_roomX);
        h.settle();
        h.connect();
        h.joined(_roomX);

        final second = h.service.claimRoom(_roomX);
        h.settle();
        h.service.releaseClaim(second);
        h.settle();

        expect(h.socket.sentEvents, ['join_room']);
      });
    });

    test('releasing the last claim leaves the room', () {
      _runFake((h) {
        final claim = h.service.claimRoom(_roomX);
        h.settle();
        h.connect();
        h.joined(_roomX);

        h.service.releaseClaim(claim);
        h.service.releaseClaim(claim);
        h.settle();

        expect(h.socket.sentEvents, ['join_room', 'leave_room']);
        expect(h.service.openChat.value, OpenChat.none);
      });
    });

    test('releasing a room ends every claim on it, threads included', () {
      _runFake((h) {
        h.service.claimRoom(_roomX);
        h.settle();
        h.connect();
        h.joined(_roomX);
        h.service.claimRoom(_roomX, threadId: 'thread-1');
        h.settle();

        h.service.releaseRoom('room-x');
        h.settle();

        expect(h.service.claims, isEmpty);
        expect(h.socket.sentEvents.last, 'leave_room');
      });
    });

    test('open_thread goes out only after room_joined, even from another room',
        () {
      _runFake((h) {
        h.service.claimRoom(_roomY);
        h.settle();
        h.connect();
        h.joined(_roomY);

        // A reply push opens a thread of room X over room Y.
        h.service.claimRoom(_roomX, threadId: 'thread-1');
        h.settle();
        expect(h.socket.sentEvents, ['join_room', 'join_room']);

        h.joined(_roomX);

        expect(h.socket.sentEvents, ['join_room', 'join_room', 'open_thread']);
        expect(h.socket.sentFor('open_thread').single.data,
            {'threadId': 'thread-1'});
      });
    });

    test('a thread opened with no room screen below opens once joined', () {
      _runFake((h) {
        final thread = h.service.claimRoom(_roomX, threadId: 'thread-1');
        h.settle();
        h.connect();
        h.joined(_roomX);
        expect(h.socket.sentEvents, ['join_room', 'open_thread']);

        h.service.releaseClaim(thread);
        h.settle();

        expect(h.socket.sentEvents, ['join_room', 'open_thread', 'leave_room']);
      });
    });

    test('closing a thread over its room closes it and stays in the room', () {
      _runFake((h) {
        h.openChat(_roomX, threadId: null);
        final thread = h.service.claimRoom(_roomX, threadId: 'thread-1');
        h.settle();
        expect(h.socket.sentEvents.last, 'open_thread');

        h.service.releaseClaim(thread);
        h.settle();

        expect(
            h.socket.sentEvents, ['join_room', 'open_thread', 'close_thread']);
      });
    });

    test('a screen coming back on top takes the socket back', () {
      _runFake((h) {
        final room = h.openChat(_roomX);
        final dm = h.openChat(_dm);

        // Popping the DM: the room below is re-activated first.
        h.service.activateClaim(room);
        h.service.releaseClaim(dm);
        h.settle();

        expect(h.socket.joinRequests, ['room-x', 'room-d', 'room-x']);
        expect(h.service.claims.single, room);
      });
    });

    test(
        'a reconnect with two claims joins only the top one, even 200 ms '
        'later', () {
      _runFake((h) {
        h.service.claimRoom(_roomX);
        h.settle();
        h.connect();
        h.joined(_roomX);
        h.openChat(_dm);

        h.socket.serverDisconnect();
        h.async.elapse(const Duration(seconds: 2));
        expect(h.socket.connectCalls, 2);
        h.connect();
        h.async.elapse(const Duration(milliseconds: 200));

        expect(h.socket.joinRequests, ['room-x', 'room-d', 'room-d']);
        expect(h.socket.sent.every((packet) => packet.whileConnected), isTrue);
      });
    });

    test('a chat opened just after a reconnect is not undone by a late rejoin',
        () {
      _runFake((h) {
        h.openChat(_roomX);
        h.socket.serverDisconnect();
        h.async.elapse(const Duration(seconds: 2));

        h.socket.acceptConnection();
        h.service.claimRoom(_dm);
        h.settle();
        h.async.elapse(const Duration(milliseconds: 200));

        expect(h.socket.joinRequests, ['room-x', 'room-d']);
      });
    });

    test('claims made while disconnected are joined on connect, newest only',
        () {
      _runFake((h) {
        final room = h.service.claimRoom(_roomX);
        h.service.claimRoom(_dm);
        h.service.releaseClaim(room);
        h.settle();
        expect(h.socket.sent, isEmpty);

        h.connect();

        expect(h.socket.joinRequests, ['room-d']);
      });
    });

    test('a NOT_IN_ROOM event rejoins only the top claim, once', () {
      _runFake((h) {
        h.service.claimRoom(_roomX);
        h.settle();
        h.connect();
        h.joined(_roomX);
        h.openChat(_dm);

        h.socket.serverEmit('error', _notInRoomEvent);
        h.socket.serverEmit('error', _notInRoomEvent);
        h.settle();

        expect(h.socket.joinRequests, ['room-x', 'room-d', 'room-d']);
      });
    });

    test('a room_joined that arrives late for another room is corrected', () {
      _runFake((h) {
        h.openChat(_roomX);
        h.service.claimRoom(_dm);
        h.settle();
        h.joined(_dm);

        // An older backend finishes the earlier join last.
        h.joined(_roomX);

        expect(h.socket.joinRequests, ['room-x', 'room-d', 'room-d']);
      });
    });

    test('a newer claim replaces a join that is still on its way', () {
      _runFake((h) {
        h.openChat(_roomX);
        final dm = h.service.claimRoom(_dm);
        h.settle();
        h.service.releaseClaim(dm);
        h.settle();

        // Back on room X before the DM opened: ask for X again, so the
        // server's last request is X.
        expect(h.socket.joinRequests, ['room-x', 'room-d', 'room-x']);
      });
    });
  });

  group('SocketService sends', () {
    test('names the room and the thread it is for', () {
      _runFake((h) {
        h.openChat(_roomX);

        h.service.sendMessage('hi', room: _roomX, parentMessageId: 'thread-1');
        h.settle();

        expect(h.socket.sentFor('send_message').single.data, {
          'text': 'hi',
          'roomId': 'room-x',
          'parentMessageId': 'thread-1',
        });
      });
    });

    test(
        'a send for another room is refused locally, then retried once '
        'after the rejoin, and two sends share one join', () {
      _runFake((h) {
        h.openChat(_roomX);
        h.service.claimRoom(_roomY);
        h.settle();

        // Room Y is on top, but the socket is still in room X.
        final first = h.send('one', _roomY);
        final second = h.send('two', _roomY);
        expect(h.socket.sentFor('send_message'), isEmpty);
        expect(h.socket.joinRequests, ['room-x', 'room-y']);

        h.joined(_roomY);
        final sends = h.socket.sentFor('send_message');
        expect(sends.map((packet) => packet.data), [
          {'text': 'one', 'roomId': 'room-y'},
          {'text': 'two', 'roomId': 'room-y'},
        ]);
        for (final packet in sends) {
          packet.reply({'ok': true});
        }
        h.settle();

        expect(first.single.isSent, isTrue);
        expect(second.single.isSent, isTrue);
        expect(h.socket.joinRequests, ['room-x', 'room-y']);
      });
    });

    test('a NOT_IN_ROOM answer causes one rejoin and one retry', () {
      _runFake((h) {
        h.openChat(_roomX);

        final result = h.send('hello', _roomX);
        // The server lost the room: an error event, then the answer.
        h.socket.serverEmit('error', _notInRoomEvent);
        h.socket.sentFor('send_message').single.reply({
          'ok': false,
          'error': _notInRoomEvent['error'],
        });
        h.settle();
        expect(h.socket.joinRequests, ['room-x', 'room-x']);

        h.joined(_roomX);
        final sends = h.socket.sentFor('send_message');
        expect(sends, hasLength(2));
        sends.last.reply({'ok': true});
        h.settle();

        expect(result.single.isSent, isTrue);
      });
    });

    test('a send for a room that is no longer on top is not retried', () {
      _runFake((h) {
        h.openChat(_roomX);
        h.openChat(_dm);

        final result = h.send('late', _roomX);

        expect(result.single.error?.code, SocketService.notInRoomCode);
        expect(h.socket.sentFor('send_message'), isEmpty);
        expect(h.socket.joinRequests, ['room-x', 'room-d']);
      });
    });

    test('a failed rejoin returns the join error', () {
      _runFake((h) {
        h.openChat(_roomX);
        h.service.claimRoom(_roomY);
        h.settle();

        final result = h.send('hello', _roomY);
        h.socket.sentFor('join_room').last.reply({
          'ok': false,
          'error': {
            'code': 'FORBIDDEN',
            'message': 'You are not allowed to join this chat.',
          },
        });
        h.settle();

        expect(result.single.error?.message,
            'You are not allowed to join this chat.');
        expect(h.socket.sentFor('send_message'), isEmpty);
      });
    });

    test('gives up after 5 s when the room is not joined again', () {
      _runFake((h) {
        h.openChat(_roomX);
        h.service.claimRoom(_roomY);
        h.settle();

        final result = h.send('hello', _roomY);
        h.async.elapse(const Duration(seconds: 5));

        expect(result.single.error?.code, SocketService.notInRoomCode);
        expect(h.socket.sentFor('send_message'), isEmpty);
      });
    });
  });

  group('SocketService join failures', () {
    test(
        'a refusal reports the server reason and is not retried until Try '
        'again', () {
      _runFake((h) {
        h.service.claimRoom(_roomX);
        h.settle();
        h.connect();

        h.socket.sentFor('join_room').single.reply({
          'ok': false,
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'You can only join up to 5 group chats at a time.',
          },
        });
        h.settle();

        expect(h.failures.single.roomId, 'room-x');
        expect(h.failures.single.isRefusal, isTrue);
        expect(h.failures.single.error.message,
            'You can only join up to 5 group chats at a time.');

        h.async.elapse(const Duration(seconds: 30));
        expect(h.socket.joinRequests, ['room-x']);
        expect(h.failures, hasLength(1));

        h.service.retryJoin(_roomX);
        h.settle();
        expect(h.socket.joinRequests, ['room-x', 'room-x']);
      });
    });

    test('a refusal leaves the room the socket was still in', () {
      _runFake((h) {
        h.openChat(_roomX);
        h.service.claimRoom(_roomY);
        h.settle();

        h.socket.sentFor('join_room').last.reply({
          'ok': false,
          'error': {'code': 'FORBIDDEN', 'message': 'Not allowed.'},
        });
        h.settle();

        expect(h.socket.sentEvents.last, 'leave_room');
      });
    });

    test(
        'a join without room_joined fails after 10 s, and a late one still '
        'opens the chat', () {
      _runFake((h) {
        h.service.claimRoom(_roomX);
        h.settle();
        h.connect();

        h.async.elapse(const Duration(seconds: 9));
        expect(h.failures, isEmpty);
        h.async.elapse(const Duration(seconds: 1));

        expect(h.failures.single.error.code, SocketService.joinTimeoutCode);
        expect(h.failures.single.error.message,
            'Check your connection and try again.');
        expect(h.failures.single.isRefusal, isFalse);

        h.joined(_roomX);
        h.send('made it', _roomX);
        expect(h.socket.sentFor('send_message'), hasLength(1));
      });
    });

    test(
        'a chat that cannot connect fails as not connected, and a reconnect '
        'tries it again', () {
      _runFake((h) {
        h.service.claimRoom(_roomX);
        h.async.elapse(const Duration(seconds: 10));

        expect(h.failures.single.error.code, SocketService.notConnectedCode);

        h.connect();
        expect(h.socket.joinRequests, ['room-x']);
      });
    });

    test('answers to older or replaced joins are ignored', () {
      _runFake((h) {
        h.service.claimRoom(_roomX);
        h.settle();
        h.connect();
        h.service.claimRoom(_dm);
        h.settle();
        final joins = h.socket.sentFor('join_room');
        expect(joins, hasLength(2));

        joins.first.reply({
          'ok': false,
          'error': {'code': 'FORBIDDEN', 'message': 'Not allowed.'},
        });
        joins.last.reply({'ok': false, 'superseded': true});
        h.settle();

        expect(h.failures, isEmpty);
      });
    });

    test('another screen on top gets a fresh try', () {
      _runFake((h) {
        final room = h.service.claimRoom(_roomX);
        h.settle();
        h.connect();
        h.socket.sentFor('join_room').single.reply({
          'ok': false,
          'error': {'code': 'FORBIDDEN', 'message': 'Not allowed.'},
        });
        h.settle();

        final dm = h.openChat(_dm);
        h.service.activateClaim(room);
        h.service.releaseClaim(dm);
        h.settle();

        expect(h.socket.joinRequests, ['room-x', 'room-d', 'room-x']);
      });
    });
  });

  group('SocketService.requestRoomSnapshot', () {
    test('asks again for a room joined for another screen', () {
      _runFake((h) {
        h.openChat(_roomX, threadId: 'thread-1');
        h.service.claimRoom(_roomX);
        h.settle();
        expect(
            h.socket.sentEvents, ['join_room', 'open_thread', 'close_thread']);

        h.service.requestRoomSnapshot(_roomX);
        h.settle();

        expect(h.socket.joinRequests, ['room-x', 'room-x']);
      });
    });

    test('does nothing for a room that is not on top or still joining', () {
      _runFake((h) {
        h.openChat(_roomX);
        h.service.claimRoom(_dm);
        h.settle();

        h.service.requestRoomSnapshot(_roomX);
        h.service.requestRoomSnapshot(_dm);
        h.settle();

        expect(h.socket.joinRequests, ['room-x', 'room-d']);
      });
    });
  });

  group('SocketService.openChat', () {
    OpenChat openChatFor(void Function(SocketService service) claims) {
      late OpenChat openChat;
      fakeAsync((async) {
        final service = SocketService();
        claims(service);
        async.flushMicrotasks();
        openChat = service.openChat.value;
      });
      return openChat;
    }

    test('is the room on top, with its thread when opened from the room', () {
      expect(
        openChatFor((service) => service.claimRoom(_roomX)),
        const OpenChat(roomId: 'room-x'),
      );
      expect(
        openChatFor((service) {
          service.claimRoom(_roomX);
          service.claimRoom(_roomX, threadId: 'thread-1');
        }),
        const OpenChat(roomId: 'room-x', threadId: 'thread-1'),
      );
    });

    test('is only the thread when no screen of its room is right below', () {
      expect(
        openChatFor(
          (service) => service.claimRoom(_roomX, threadId: 'thread-1'),
        ),
        const OpenChat(threadId: 'thread-1'),
      );
      expect(
        openChatFor((service) {
          service.claimRoom(_roomY);
          service.claimRoom(_roomX, threadId: 'thread-1');
        }),
        const OpenChat(threadId: 'thread-1'),
      );
    });

    test('changes after the current change, not during it', () {
      fakeAsync((async) {
        final service = SocketService();
        final changes = <OpenChat>[];
        service.openChat.addListener(() => changes.add(service.openChat.value));

        final room = service.claimRoom(_roomX);
        final dm = service.claimRoom(_dm);
        expect(changes, isEmpty);
        async.flushMicrotasks();
        expect(changes, [const OpenChat(roomId: 'room-d')]);

        service.activateClaim(room);
        service.releaseClaim(dm);
        async.flushMicrotasks();
        expect(changes.last, const OpenChat(roomId: 'room-x'));
      });
    });
  });

  group('SocketService sign-out', () {
    test('clearing the token ends every claim', () {
      _runFake((h) {
        h.openChat(_roomX);
        h.service.claimRoom(_dm);

        h.service.setToken(null);
        h.settle();

        expect(h.service.claims, isEmpty);
        expect(h.service.openChat.value, OpenChat.none);
        expect(h.socket.disconnectCalls, 1);
        expect(h.socket.connected, isFalse);
      });
    });

    test('disconnect ends every claim, so the next session starts clean', () {
      _runFake((h) {
        h.openChat(_roomX);

        h.service.disconnect();
        h.settle();
        expect(h.service.claims, isEmpty);
        expect(h.service.openChat.value, OpenChat.none);

        h.service.setToken('token-3');
        h.service.claimRoom(_roomY);
        h.settle();
        h.connect();

        expect(h.sockets, hasLength(2));
        expect(h.socket.joinRequests, ['room-y']);
        expect(h.failures, isEmpty);
      });
    });
  });

  group('SocketService reconnects', () {
    test('a dropped connection rejoins the newest claim when it comes back',
        () {
      _runFake((h) {
        h.service.claimRoom(_roomX);
        h.settle();
        h.connect();
        h.joined(_roomX);
        final dm = h.openChat(_dm);

        h.socket.dropConnection();
        // The DM closes while offline: nothing is queued for later.
        h.service.releaseClaim(dm);
        h.settle();
        h.async.elapse(const Duration(seconds: 5));
        expect(h.socket.connectCalls, 1);

        // socket.io reconnects by itself after a network drop.
        h.connect();

        expect(h.socket.joinRequests, ['room-x', 'room-d', 'room-x']);
        expect(h.socket.sent.every((packet) => packet.whileConnected), isTrue);
      });
    });

    test('a server disconnect reconnects with backoff and rejoins', () {
      _runFake((h) {
        h.openChat(_roomX);

        h.socket.serverDisconnect();
        h.async.elapse(const Duration(milliseconds: 900));
        expect(h.socket.connectCalls, 1);
        h.async.elapse(const Duration(milliseconds: 500));
        expect(h.socket.connectCalls, 2);

        h.connect();

        expect(h.socket.joinRequests, ['room-x', 'room-x']);
      });
    });

    test('TOKEN_EXPIRED refreshes the token, reconnects with it and rejoins',
        () {
      _runFake((h) {
        h.openChat(_roomX, threadId: 'thread-1');

        h.socket.serverEmit('error', _tokenExpiredEvent);
        h.socket.serverDisconnect();
        h.settle();

        expect(h.refreshCalls, 1);
        expect(h.socket.connectCalls, 2);
        expect(h.socket.handshakeToken, 'token-2');

        h.connect();
        h.joined(_roomX);

        expect(h.socket.sentEvents, [
          'join_room',
          'open_thread',
          'join_room',
          'open_thread',
        ]);
        expect(h.fatalMessages, isEmpty);
      });
    });

    test('a ban signs out with the reason and never reconnects', () {
      _runFake((h) {
        h.openChat(_roomX);

        h.socket.refuseHandshake(
          {'message': 'Account blocked: Your account has been banned.'},
        );
        h.async.elapse(const Duration(minutes: 2));

        expect(h.fatalMessages, ['Your account has been banned.']);
        expect(h.refreshCalls, 0);
        expect(h.socket.connectCalls, 1);
      });
    });

    test('a server outage retries later and never signs out', () {
      _runFake((h) {
        h.service.claimRoom(_roomX);
        h.settle();

        h.socket.refuseHandshake(
          {'message': 'Server unavailable: please try again shortly.'},
        );
        h.async.elapse(const Duration(seconds: 2));

        expect(h.socket.connectCalls, 2);
        expect(h.refreshCalls, 0);
        expect(h.fatalMessages, isEmpty);

        h.connect();
        expect(h.socket.joinRequests, ['room-x']);
      });
    });

    test('a connection that never opens times out after 25 s', () {
      _runFake((h) {
        var finished = false;
        h.service.ensureConnectedForUserChannel().then((_) => finished = true);

        h.async.elapse(const Duration(seconds: 24));
        expect(finished, isFalse);
        h.async.elapse(const Duration(seconds: 1));

        expect(finished, isTrue);
      });
    });
  });

  group('SocketService in the background', () {
    test('background disconnects once, and nothing reconnects over two minutes',
        () {
      _runFake((h) {
        h.openChat(_roomX);
        h.service.claimRoom(_roomX, threadId: 'thread-1');
        h.settle();

        h.service.setForeground(false);
        h.service.setForeground(false);
        h.settle();

        expect(h.socket.disconnectCalls, 1);
        expect(h.socket.connected, isFalse);

        // Nothing that connects in the foreground connects now.
        h.service.claimRoom(_dm);
        h.service.ensureConnectedForUserChannel();
        h.service.retryJoin(_dm);
        h.settle();
        h.async.elapse(const Duration(minutes: 2));

        expect(h.socket.connectCalls, 1);
        expect(h.failures, isEmpty);
        // The server ends the room and the thread with the connection, and
        // the screens keep their claims for the return.
        expect(h.socket.sentEvents, ['join_room', 'open_thread']);
        expect(
          h.service.claims.map((claim) => claim.room.id),
          ['room-x', 'room-x', 'room-d'],
        );
      });
    });

    test('a reconnect that was due when the app left is called off', () {
      _runFake((h) {
        h.openChat(_roomX);
        // A deploy ends the connection: a retry is due in about a second.
        h.socket.serverDisconnect();

        h.service.setForeground(false);
        h.async.elapse(const Duration(minutes: 2));

        expect(h.socket.connectCalls, 1);
      });
    });

    test('foreground reconnects, rejoins the top claim and reopens the thread',
        () {
      _runFake((h) {
        h.openChat(_roomX);
        h.service.claimRoom(_roomX, threadId: 'thread-1');
        h.settle();
        h.service.setForeground(false);
        h.async.elapse(const Duration(minutes: 5));

        h.service.setForeground(true);
        h.settle();
        expect(h.socket.connectCalls, 2);
        h.connect();
        h.joined(_roomX);

        expect(h.socket.sentEvents, [
          'join_room',
          'open_thread',
          'join_room',
          'open_thread',
        ]);
        expect(h.socket.sent.every((packet) => packet.whileConnected), isTrue);
        expect(
          h.service.openChat.value,
          const OpenChat(roomId: 'room-x', threadId: 'thread-1'),
        );
        expect(h.failures, isEmpty);
      });
    });

    test(
        'background while a connect is pending, then foreground within 25 s, '
        'starts a new connect and rejoins the top claim', () {
      _runFake((h) {
        var firstAttemptEnded = false;
        h.service.claimRoom(_roomX);
        h.service
            .ensureConnectedForUserChannel()
            .then((_) => firstAttemptEnded = true);
        h.settle();
        expect(h.socket.connectCalls, 1);
        h.async.elapse(const Duration(seconds: 5));

        h.service.setForeground(false);
        h.settle();
        // Nobody waits for a connect that was given up.
        expect(firstAttemptEnded, isTrue);
        h.async.elapse(const Duration(seconds: 10));

        h.service.setForeground(true);
        h.settle();
        expect(h.socket.connectCalls, 2);
        h.async.elapse(const Duration(seconds: 5));
        h.connect();
        h.joined(_roomX);
        // Well past the first attempt's 25 s: nothing of it is left to fail.
        h.async.elapse(const Duration(seconds: 30));

        expect(h.socket.joinRequests, ['room-x']);
        expect(h.socket.connected, isTrue);
        expect(h.failures, isEmpty);
      });
    });

    test("a token refresh that finishes in the background doesn't connect", () {
      _runFake((h) {
        final refreshed = Completer<String?>();
        h.service.refreshToken = () => refreshed.future;
        h.openChat(_roomX);
        h.socket.serverEmit('error', _tokenExpiredEvent);
        h.socket.serverDisconnect();
        h.settle();

        h.service.setForeground(false);
        refreshed.complete('token-2');
        h.settle();
        h.async.elapse(const Duration(minutes: 2));
        expect(h.socket.connectCalls, 1);

        h.service.setForeground(true);
        h.settle();
        expect(h.socket.connectCalls, 2);
        expect(h.socket.handshakeToken, 'token-2');
        h.connect();

        expect(h.socket.joinRequests, ['room-x', 'room-x']);
      });
    });

    test('a refresh still running at the return connects once it is done', () {
      _runFake((h) {
        final refreshed = Completer<String?>();
        h.service.refreshToken = () => refreshed.future;
        h.openChat(_roomX);
        h.socket.serverEmit('error', _tokenExpiredEvent);
        h.socket.serverDisconnect();
        h.settle();

        h.service.setForeground(false);
        h.service.setForeground(true);
        h.settle();
        expect(h.socket.connectCalls, 1);

        refreshed.complete('token-2');
        h.settle();

        expect(h.socket.connectCalls, 2);
        expect(h.socket.handshakeToken, 'token-2');
      });
    });
  });

  group('SocketService.resyncRequests', () {
    test('fires once after each reconnect, and not on the first connect', () {
      _runFake((h) {
        h.openChat(_roomX);
        expect(h.resyncs, 0);

        h.socket.dropConnection();
        // socket.io reconnects by itself after a network drop.
        h.connect();
        expect(h.resyncs, 1);

        h.socket.serverDisconnect();
        h.async.elapse(const Duration(seconds: 2));
        h.connect();
        expect(h.resyncs, 2);
      });
    });

    test('one return to the foreground causes one resync, once reconnected',
        () {
      _runFake((h) {
        h.openChat(_roomX);

        h.service.setForeground(false);
        h.service.setForeground(true);
        h.settle();
        expect(h.resyncs, 0);

        h.connect();
        h.joined(_roomX);
        h.async.elapse(const Duration(minutes: 1));

        expect(h.resyncs, 1);
      });
    });

    test('a return whose reconnect fails resyncs right away, and only once',
        () {
      _runFake((h) {
        h.openChat(_roomX);
        h.service.setForeground(false);
        h.service.setForeground(true);
        h.settle();

        // WebSockets are blocked: the lists still catch up over HTTP.
        h.socket.failConnection();
        h.settle();
        expect(h.resyncs, 1);

        // socket.io keeps trying.
        h.socket.failConnection();
        h.async.elapse(const Duration(seconds: 30));
        expect(h.resyncs, 1);

        // Once it gets through, it's a reconnect like any other.
        h.connect();
        expect(h.resyncs, 2);
      });
    });

    test('a return whose reconnect never answers resyncs after 25 s', () {
      _runFake((h) {
        h.openChat(_roomX);
        h.service.setForeground(false);
        h.service.setForeground(true);

        h.async.elapse(const Duration(seconds: 24));
        expect(h.resyncs, 0);
        h.async.elapse(const Duration(seconds: 1));

        expect(h.resyncs, 1);
      });
    });

    test('a return the server turns away for now resyncs before the retry', () {
      _runFake((h) {
        h.openChat(_roomX);
        h.service.setForeground(false);
        h.service.setForeground(true);
        h.settle();

        h.socket.refuseHandshake(
          {'message': 'Server unavailable: please try again shortly.'},
        );
        h.settle();
        expect(h.resyncs, 1);

        h.async.elapse(const Duration(seconds: 2));
        expect(h.socket.connectCalls, 3);
        h.connect();
        expect(h.resyncs, 2);
      });
    });

    test('the first connect resyncs when a list failed to load', () {
      _runFake((h) {
        h.service.requestResyncOnConnect();
        h.service.ensureConnectedForUserChannel();
        h.settle();

        h.connect();

        expect(h.resyncs, 1);
      });
    });

    test("a new session's first connect is not a reconnect", () {
      _runFake((h) {
        h.openChat(_roomX);

        h.service.disconnect();
        h.service.setToken('token-3');
        h.service.ensureConnectedForUserChannel();
        h.settle();
        h.connect();

        expect(h.sockets, hasLength(2));
        expect(h.resyncs, 0);
      });
    });
  });
}
