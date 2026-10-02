import 'package:bleya/data/dtos/push_notification_payload_dto.dart';
import 'package:bleya/domain/entities/push_notification_payload.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  test('parses message payload', () {
    final payload = PushNotificationPayloadDto.fromJson(messagePushDataJson());

    expect(payload.type, PushNotificationType.message);
    expect(payload.roomId, FixtureIds.directRoom);
    expect(payload.messageId, FixtureIds.message);
    expect(payload.senderId, FixtureIds.otherUser);
    expect(payload.threadId, isNull);
    expect(payload.notificationId, isNull);
  });

  test('parses reply payload', () {
    final payload = PushNotificationPayloadDto.fromJson(replyPushDataJson());

    expect(payload.type, PushNotificationType.reply);
    expect(payload.isReply, isTrue);
    expect(payload.roomId, FixtureIds.cityRoom);
    expect(payload.threadId, FixtureIds.message);
    expect(payload.notificationId, FixtureIds.notification);
  });

  test('throws when reply payload is missing threadId', () {
    expect(
      () => PushNotificationPayloadDto.fromJson(
        replyPushDataJson()..remove('threadId'),
      ),
      throwsFormatException,
    );
  });

  test('throws for a push type the app does not know', () {
    expect(
      () => PushNotificationPayloadDto.fromJson(
        messagePushDataJson()..['type'] = 'mention',
      ),
      throwsFormatException,
    );
  });

  test('a blank notificationId reads as none', () {
    final payload = PushNotificationPayloadDto.fromJson(
      replyPushDataJson()..['notificationId'] = '  ',
    );

    expect(payload.notificationId, isNull);
  });
}
