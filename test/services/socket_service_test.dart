import 'package:bleya/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('SocketService.sendMessage', () {
    test('fails right away instead of dropping the text when offline',
        () async {
      final result = await SocketService().sendMessage('hello');

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
}
