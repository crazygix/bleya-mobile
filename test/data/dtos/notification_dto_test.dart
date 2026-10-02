import 'package:bleya/data/dtos/notification_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  test('parses an item of GET /notifications', () {
    final notification = NotificationDto.fromJson(notificationJson());

    expect(notification.id, FixtureIds.notification);
    expect(notification.senderId, FixtureIds.otherUser);
    expect(notification.senderName, 'ana');
    expect(notification.senderAvatarUrl, isNull);
    expect(notification.type, 'reply');
    expect(notification.roomId, FixtureIds.cityRoom);
    expect(notification.roomName, 'Belgrade, Serbia');
    expect(notification.roomType, 'public');
    expect(notification.messageId, FixtureIds.reply);
    expect(notification.threadId, FixtureIds.message);
    expect(
      notification.parentMessageText,
      'Anyone up for coffee near Knez Mihailova?',
    );
    expect(notification.replyText, 'Count me in!');
    expect(notification.previewText, 'Count me in!');
    expect(notification.isRead, isFalse);
    expect(notification.isDismissed, isFalse);
    expect(
      notification.createdAt,
      DateTime.fromMillisecondsSinceEpoch(FixtureTimes.replied),
    );
  });

  test('reads a read item as read', () {
    expect(
        NotificationDto.fromJson(notificationJson(read: true)).isRead, isTrue);
  });

  test('parses the new_notification event the same way', () {
    final fromList = NotificationDto.fromJson(notificationJson());
    final fromEvent = NotificationDto.fromJson(notificationEventJson());

    expect(fromEvent.id, fromList.id);
    expect(fromEvent.senderName, fromList.senderName);
    expect(fromEvent.threadId, fromList.threadId);
    expect(fromEvent.createdAt, fromList.createdAt);
  });

  test('a sender sent as a bare id shows as Unknown', () {
    final json = notificationJson()..['sender'] = FixtureIds.otherUser;

    final notification = NotificationDto.fromJson(json);

    expect(notification.senderId, FixtureIds.otherUser);
    expect(notification.senderName, 'Unknown');
    expect(notification.senderAvatarUrl, isNull);
  });

  test('rejects an item without a sender name', () {
    final json = notificationJson()
      ..['sender'] = {'id': FixtureIds.otherUser, 'profileImageUrl': null};

    expect(() => NotificationDto.fromJson(json), throwsFormatException);
  });

  test('rejects a createdAt that is not milliseconds', () {
    final json = notificationJson()..['createdAt'] = '1767269100000';

    expect(() => NotificationDto.fromJson(json), throwsFormatException);
  });
}
