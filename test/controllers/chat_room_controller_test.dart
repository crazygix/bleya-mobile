import 'package:bleya/domain/entities/message.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/domain/repositories/message_repository.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/chat_room_providers.dart';
import 'package:bleya/providers/use_case_providers.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:bleya/use_cases/message/get_thread_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetThreadUseCase extends Mock implements GetThreadUseCase {}

/// Socket double that behaves like the backend for sends: a failed send is
/// reported as an 'error' event and then in the acknowledgement.
class FakeSocketService extends SocketService {
  final Map<String, List<Function(Map<String, dynamic>)>> listeners = {};
  final List<SendMessageResult> sendResults = [];
  final List<String> sentTexts = [];
  int forcedJoins = 0;

  /// Runs while a send waits for its acknowledgement.
  void Function()? duringSend;

  void emit(String event, Map<String, dynamic> data) {
    for (final listener in List.of(listeners[event] ?? const [])) {
      listener(data);
    }
  }

  @override
  dynamic addListener(String event, Function(Map<String, dynamic>) callback) {
    listeners.putIfAbsent(event, () => []).add(callback);
    return callback;
  }

  @override
  void removeListener(String event, dynamic handler) {
    listeners[event]?.remove(handler);
  }

  @override
  Future<void> joinRoom(Room room, {bool force = false}) async {
    if (!force) return;
    forcedJoins++;
    emit('room_joined', {
      'room': {'id': room.id, 'name': room.name},
      'messages': const [],
      'pagination': {'hasMore': false},
    });
  }

  @override
  Future<SendMessageResult> sendMessage(
    String text, {
    String? parentMessageId,
  }) async {
    sentTexts.add(text);
    duringSend?.call();
    final result = sendResults.removeAt(0);
    final error = result.error;
    if (error != null) {
      emit('error', {
        'error': {'code': error.code, 'message': error.message},
      });
    }
    return result;
  }
}

SendMessageResult _failed(String code, String message) {
  return SendMessageResult.failed(
      SocketErrorData(code: code, message: message));
}

Message _message(String id, {String userId = 'user-2', int replyCount = 0}) {
  return Message(
    id: id,
    roomId: 'room-1',
    userId: userId,
    username: 'bob',
    text: 'hi',
    createdAt: DateTime(2026, 1, 1),
    replyCount: replyCount,
  );
}

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

    test(
        'returns why a rejected message was not stored, without a '
        'duplicate toast from the error event', () async {
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

    test('rejoins and retries once when the server lost the room', () async {
      final toasts = <String>[];
      controller().errorMessages.listen(toasts.add);
      socket.sendResults.addAll([
        _failed(SocketService.notInRoomCode, 'Not in a room.'),
        const SendMessageResult.sent(null),
      ]);

      final result = await controller().sendMessage('hello');
      await pumpEventQueue();

      expect(result.isSent, isTrue);
      expect(socket.forcedJoins, 1);
      expect(socket.sentTexts, ['hello', 'hello']);
      expect(toasts, isEmpty);
    });

    test('sends that lose the room at the same time share one rejoin',
        () async {
      socket.sendResults.addAll([
        _failed(SocketService.notInRoomCode, 'Not in a room.'),
        _failed(SocketService.notInRoomCode, 'Not in a room.'),
        const SendMessageResult.sent(null),
        const SendMessageResult.sent(null),
      ]);

      final results = await Future.wait([
        controller().sendMessage('one'),
        controller().sendMessage('two'),
      ]);

      expect(results.every((result) => result.isSent), isTrue);
      expect(socket.forcedJoins, 1);
    });

    test('still shows an unrelated error that arrives during a send', () async {
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

    test(
        'a NOT_IN_ROOM error outside a send forces a rejoin, matched by '
        'code', () async {
      controller();
      socket.emit('error', {
        'error': {'code': 'NOT_IN_ROOM', 'message': 'Reopen the chat.'},
      });

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(socket.forcedJoins, 1);
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

  group('ThreadController', () {
    late MockGetThreadUseCase getThread;

    setUp(() {
      getThread = MockGetThreadUseCase();
      when(() => getThread('parent-1')).thenAnswer(
        (_) async => ThreadData(
          parentMessage: _message('parent-1'),
          replies: [_message('reply-1'), _message('reply-2')],
        ),
      );
      container.dispose();
      container = ProviderContainer(
        overrides: [
          tokenProvider.overrideWith((ref) => 'token'),
          socketServiceProvider.overrideWithValue(socket),
          getThreadUseCaseProvider.overrideWithValue(getThread),
        ],
      );
      keepAlive(threadMessagesProvider('parent-1'));
    });

    test('flags the thread for closing when its parent is removed', () async {
      keepAlive(threadParentRemovedProvider('parent-1'));
      container.read(threadMessagesProvider('parent-1').notifier);
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
      container.read(threadMessagesProvider('parent-1').notifier);
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
      container.read(threadMessagesProvider('parent-1').notifier);
      await pumpEventQueue();

      socket.emit('message_removed', {
        'messageId': 'reply-1',
        'roomId': room.id,
        'parentMessageId': 'parent-1',
      });

      final replies =
          container.read(threadMessagesProvider('parent-1')).value!.replies;
      expect(replies.map((r) => r.id), ['reply-2']);
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

    test('the blocked set resets when the session changes', () {
      container.read(sessionBlockedUserIdsProvider.notifier).state = {
        'user-2',
      };

      container.read(sessionVersionProvider.notifier).state++;

      expect(container.read(sessionBlockedUserIdsProvider), isEmpty);
    });
  });
}
