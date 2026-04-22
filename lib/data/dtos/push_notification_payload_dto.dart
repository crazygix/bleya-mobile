import '../../domain/entities/push_notification_payload.dart';

class PushNotificationPayloadDto {
  static PushNotificationType _parseType(String value) {
    switch (value) {
      case 'message':
        return PushNotificationType.message;
      case 'reply':
        return PushNotificationType.reply;
      default:
        throw FormatException('Unsupported push notification type: $value');
    }
  }

  static String _requireString(Map<String, dynamic> data, String fieldName) {
    final value = data[fieldName];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing or invalid "$fieldName" in push payload');
    }

    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> data, String fieldName) {
    final value = data[fieldName];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return value.trim();
  }

  static PushNotificationPayload fromJson(Map<String, dynamic> data) {
    final type = _parseType(_requireString(data, 'type'));
    final threadId = _optionalString(data, 'threadId');

    if (type == PushNotificationType.reply && threadId == null) {
      throw const FormatException('Reply push payload requires "threadId"');
    }

    return PushNotificationPayload(
      type: type,
      roomId: _requireString(data, 'roomId'),
      messageId: _requireString(data, 'messageId'),
      senderId: _requireString(data, 'senderId'),
      threadId: threadId,
      notificationId: _optionalString(data, 'notificationId'),
    );
  }
}
