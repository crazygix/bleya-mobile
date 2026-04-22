import 'package:bleya/data/dtos/push_notification_payload_dto.dart';
import 'package:bleya/domain/entities/push_notification_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses message payload', () {
    final payload = PushNotificationPayloadDto.fromJson({
      'type': 'message',
      'roomId': 'room-1',
      'messageId': 'message-1',
      'senderId': 'user-1',
    });

    expect(payload.type, PushNotificationType.message);
    expect(payload.roomId, 'room-1');
    expect(payload.messageId, 'message-1');
    expect(payload.senderId, 'user-1');
    expect(payload.threadId, isNull);
    expect(payload.notificationId, isNull);
  });

  test('parses reply payload', () {
    final payload = PushNotificationPayloadDto.fromJson({
      'type': 'reply',
      'roomId': 'room-1',
      'messageId': 'message-2',
      'senderId': 'user-2',
      'threadId': 'thread-1',
      'notificationId': 'notification-1',
    });

    expect(payload.type, PushNotificationType.reply);
    expect(payload.threadId, 'thread-1');
    expect(payload.notificationId, 'notification-1');
  });

  test('throws when reply payload is missing threadId', () {
    expect(
      () => PushNotificationPayloadDto.fromJson({
        'type': 'reply',
        'roomId': 'room-1',
        'messageId': 'message-2',
        'senderId': 'user-2',
      }),
      throwsFormatException,
    );
  });
}
