import 'package:bleya/data/repositories/message_repository_impl.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_http_adapter.dart';
import '../../fixtures/api_fixtures.dart';

void main() {
  late FakeHttpAdapter server;
  late MessageRepositoryImpl repository;

  /// Answers every request with [body].
  void respondWith(Object body) {
    server = FakeHttpAdapter((_) async => jsonResponse(200, body));
    repository = MessageRepositoryImpl(fakeDio(server));
  }

  group('getRoomMessagesPage', () {
    test('GET /rooms/:roomId/messages pages back from a cursor', () async {
      respondWith(roomMessagesPageJson());
      const cursor = '1767268500000_66f0a1b2c3d4e5f6000000b0';

      final page = await repository.getRoomMessagesPage(
        FixtureIds.cityRoom,
        before: cursor,
        limit: 30,
      );

      final request = server.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/rooms/${FixtureIds.cityRoom}/messages');
      expect(request.queryParameters, {'before': cursor, 'limit': '30'});
      expect(page.messages.map((message) => message.id), [
        FixtureIds.olderMessage,
        FixtureIds.message,
      ]);
      expect(page.messages.last.replyCount, 2);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, cursor);
    });

    test('the newest page is asked for without a query', () async {
      respondWith(roomMessagesPageJson(hasMore: false));

      final page = await repository.getRoomMessagesPage(FixtureIds.cityRoom);

      expect(server.requests.single.queryParameters, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('without pagination there is nothing more to load', () async {
      respondWith({
        'messages': [messageJson()],
      });

      final page = await repository.getRoomMessagesPage(FixtureIds.cityRoom);

      expect(page.messages, hasLength(1));
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });
  });

  test('GET /messages/:messageId/thread returns the parent and replies',
      () async {
    respondWith(threadJson());

    final thread = await repository.getThread(FixtureIds.message);

    final request = server.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/messages/${FixtureIds.message}/thread');
    expect(thread.parentMessage.id, FixtureIds.message);
    expect(thread.parentMessage.replyCount, 2);
    expect(thread.replies.map((reply) => reply.id), [
      FixtureIds.reply,
      FixtureIds.secondReply,
    ]);
    expect(
      thread.replies.every((r) => r.parentMessageId == FixtureIds.message),
      isTrue,
    );
  });

  group('getMessage', () {
    test('GET /messages/:messageId', () async {
      respondWith(replyJson());

      final message = await repository.getMessage(FixtureIds.reply);

      final request = server.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/messages/${FixtureIds.reply}');
      expect(message.text, 'Count me in!');
      expect(message.parentMessageId, FixtureIds.message);
    });

    test('a removed message fails as not found', () async {
      server = FakeHttpAdapter(
        (_) async =>
            apiErrorResponse(404, 'MESSAGE_NOT_FOUND', 'Message not found'),
      );
      repository = MessageRepositoryImpl(fakeDio(server));

      await expectLater(
        repository.getMessage(FixtureIds.reply),
        throwsA(isA<NotFoundError>()),
      );
    });
  });

  test("POST /rooms/:roomId/read returns the server's read time", () async {
    respondWith(markRoomReadJson());

    final lastReadAt = await repository.markRoomAsRead(FixtureIds.cityRoom);

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/rooms/${FixtureIds.cityRoom}/read');
    expect(request.data, isNull);
    expect(lastReadAt, FixtureTimes.read);
  });
}
