import '../../domain/entities/notification.dart';

class NotificationDto {
  static String _requiredString(dynamic value, String fieldName) {
    final parsed = value?.toString() ?? '';
    if (parsed.isEmpty) {
      throw FormatException('Missing or invalid "$fieldName" in notification');
    }
    return parsed;
  }

  static bool _parseBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    return fallback;
  }

  static DateTime _parseRequiredTimestampMs(dynamic value) {
    if (value is! int) {
      throw const FormatException(
          'Invalid "createdAt" in notification: expected int milliseconds');
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  static Notification fromJson(Map<String, dynamic> json) {
    final senderData = json['sender'];
    late final String senderId;
    late final String senderName;
    String? senderAvatarUrl;

    if (senderData is Map<String, dynamic>) {
      senderId = _requiredString(senderData['id'] ?? senderData['_id'], 'sender.id');
      senderName = _requiredString(senderData['username'], 'sender.username');
      senderAvatarUrl = senderData['profileImageUrl'] as String?;
    } else if (senderData is String) {
      senderId = senderData;
      senderName = 'Unknown';
      senderAvatarUrl = null;
    } else {
      throw const FormatException('Invalid sender format in notification');
    }

    return Notification(
      id: _requiredString(json['id'] ?? json['_id'], 'id'),
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      roomId: _requiredString(json['roomId'] ?? json['room'], 'roomId'),
      roomName: json['roomName'] as String? ?? 'Unknown Room',
      roomType: json['roomType'] as String? ?? 'public',
      messageId: _requiredString(json['messageId'] ?? json['message'], 'messageId'),
      threadId: _requiredString(json['threadId'] ?? json['thread'], 'threadId'),
      parentMessageText: json['parentMessageText'] as String?,
      replyText: json['replyText'] as String?,
      previewText: json['previewText'] as String? ?? '',
      type: _requiredString(json['type'], 'type'),
      isRead: _parseBool(json['read'] ?? json['isRead']),
      isDismissed: _parseBool(json['isDismissed']),
      createdAt: _parseRequiredTimestampMs(json['createdAt']),
    );
  }

  static Map<String, dynamic> toJson(Notification notification) {
    return {
      'id': notification.id,
      'sender': {
        'id': notification.senderId,
        'username': notification.senderName,
        'profileImageUrl': notification.senderAvatarUrl,
      },
      'roomId': notification.roomId,
      'messageId': notification.messageId,
      'threadId': notification.threadId,
      'previewText': notification.previewText,
      'type': notification.type,
      'read': notification.isRead,
      'isDismissed': notification.isDismissed,
      'createdAt': notification.createdAt.millisecondsSinceEpoch,
    };
  }
}
