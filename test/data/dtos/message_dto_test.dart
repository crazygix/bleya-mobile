import 'package:bleya/data/dtos/message_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  test('parses a top-level message', () {
    final message = MessageDto.fromJson(messageJson(replyCount: 2));

    expect(message.id, FixtureIds.message);
    expect(message.roomId, FixtureIds.cityRoom);
    expect(message.userId, FixtureIds.otherUser);
    expect(message.username, 'ana');
    expect(message.text, 'Anyone up for coffee near Knez Mihailova?');
    expect(
      message.createdAt,
      DateTime.fromMillisecondsSinceEpoch(FixtureTimes.sent),
    );
    expect(message.parentMessageId, isNull);
    expect(message.replyCount, 2);
  });

  test('parses a thread reply', () {
    final reply = MessageDto.fromJson(replyJson());

    expect(reply.id, FixtureIds.reply);
    expect(reply.parentMessageId, FixtureIds.message);
    expect(reply.replyCount, 0);
  });

  test("an author without a username keeps the server's ''", () {
    expect(MessageDto.fromJson(messageJson(username: '')).username, '');
    expect(
      MessageDto.fromJson(messageJson()..remove('username')).username,
      '',
    );
  });

  test('rejects a createdAt that is not milliseconds', () {
    final json = messageJson()..['createdAt'] = '2026-01-01T12:00:00.000Z';

    expect(() => MessageDto.fromJson(json), throwsA(isA<TypeError>()));
  });
}
