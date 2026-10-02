import 'package:bleya/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/api_fixtures.dart';

/// The socket events as the backend sends them, through the parsers the
/// screens use.
void main() {
  final service = SocketService();

  group('room_joined', () {
    test('a city room with its newest messages and read position', () {
      final joined = service.parseRoomJoinedPayload(roomJoinedJson())!;

      expect(joined.room.id, FixtureIds.cityRoom);
      expect(joined.room.name, 'Belgrade, Serbia');
      expect(joined.room.location?.latitude, 44.80401);
      expect(joined.messages.map((message) => message.id), [
        FixtureIds.olderMessage,
        FixtureIds.message,
      ]);
      expect(joined.hasMore, isFalse);
      expect(
        joined.nextCursor,
        '${FixtureTimes.olderSent}_${FixtureIds.olderMessage}',
      );
      expect(
        joined.lastReadAt,
        DateTime.fromMillisecondsSinceEpoch(FixtureTimes.read),
      );
    });

    test('a DM nobody has written in yet', () {
      final joined = service.parseRoomJoinedPayload(directRoomJoinedJson())!;

      expect(joined.room.isPrivate, isTrue);
      expect(joined.room.otherUserId, FixtureIds.otherUser);
      expect(joined.messages, isEmpty);
      expect(joined.nextCursor, isNull);
      expect(joined.lastReadAt, isNull);
    });

    test('a room never read has no read position', () {
      final joined =
          service.parseRoomJoinedPayload(roomJoinedJson(lastReadAt: null))!;

      expect(joined.lastReadAt, isNull);
    });
  });

  test('new_message and the send acknowledgement carry the same message', () {
    final event = service.parseMessagePayload(messageJson())!;
    final acknowledged = service.parseSendMessageAck(sendMessageAckJson());

    expect(event.id, FixtureIds.message);
    expect(acknowledged.isSent, isTrue);
    expect(acknowledged.message?.id, event.id);
    expect(acknowledged.message?.createdAt, event.createdAt);
  });

  test('new_notification', () {
    final notification =
        service.parseNotificationPayload(notificationEventJson())!;

    expect(notification.id, FixtureIds.notification);
    expect(notification.threadId, FixtureIds.message);
    expect(notification.isRead, isFalse);
  });

  group('message_removed', () {
    test('a top-level message, with its author and time', () {
      final removal = service.parseMessageRemovedPayload(messageRemovedJson())!;

      expect(removal.messageId, FixtureIds.message);
      expect(removal.roomId, FixtureIds.cityRoom);
      expect(removal.parentMessageId, isNull);
      expect(removal.userId, FixtureIds.otherUser);
      expect(
        removal.createdAt,
        DateTime.fromMillisecondsSinceEpoch(FixtureTimes.sent),
      );
    });

    test('a thread reply names its thread', () {
      final removal = service.parseMessageRemovedPayload(
        messageRemovedJson(isReply: true),
      )!;

      expect(removal.messageId, FixtureIds.reply);
      expect(removal.parentMessageId, FixtureIds.message);
      expect(removal.userId, FixtureIds.me);
    });
  });

  test('a refused send carries the code and the reason', () {
    final refused = service.parseSendMessageAck({
      'ok': false,
      ...socketErrorJson(
        'NOT_IN_ROOM',
        'Not in a room. Reopen the chat and try again.',
      ),
    });
    final event = service.parseErrorPayload(socketErrorJson(
      'NOT_IN_ROOM',
      'Not in a room. Reopen the chat and try again.',
    ));

    expect(refused.isSent, isFalse);
    expect(refused.error?.code, 'NOT_IN_ROOM');
    expect(event.code, 'NOT_IN_ROOM');
    expect(event.message, 'Not in a room. Reopen the chat and try again.');
  });
}
