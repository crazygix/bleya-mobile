import '../../domain/entities/notification.dart';

class NotificationModel extends Notification {
  const NotificationModel({
    required super.id,
    required super.senderId,
    required super.senderName,
    super.senderAvatarUrl,
    required super.roomId,
    required super.messageId,
    required super.threadId,
    required super.previewText,
    required super.type,
    required super.isRead,
    required super.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Handle sender - can be either a populated object (from API) or just an ID string (from socket)
    String senderId;
    String senderName;
    String? senderAvatarUrl;

    final senderData = json['sender'];
    if (senderData is Map<String, dynamic>) {
      // API format: sender is populated
      senderId = senderData['id'] as String;
      senderName = senderData['username'] as String;
      senderAvatarUrl = senderData['profileImageUrl'] as String?;
    } else if (senderData is String) {
      // Socket format: sender is just an ID
      senderId = senderData;
      senderName = 'Unknown'; // Will need to fetch or show generic name
      senderAvatarUrl = null;
    } else {
      throw FormatException('Invalid sender format in notification');
    }

    // Handle field name variations between API and socket
    final id = (json['id'] ?? json['_id']) as String;
    final roomId = (json['roomId'] ?? json['room']) as String;
    final messageId = (json['messageId'] ?? json['message']) as String;
    final threadId = (json['threadId'] ?? json['thread']) as String;

    // Parse createdAt - can be int (milliseconds) or String (ISO)
    DateTime createdAt;
    final createdAtData = json['createdAt'];
    if (createdAtData is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtData);
    } else if (createdAtData is String) {
      createdAt = DateTime.parse(createdAtData);
    } else {
      createdAt = DateTime.now();
    }

    return NotificationModel(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      roomId: roomId,
      messageId: messageId,
      threadId: threadId,
      previewText: json['previewText'] as String? ?? '',
      type: json['type'] as String,
      isRead: json['read'] as bool,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': {
        'id': senderId,
        'username': senderName,
        'profileImageUrl': senderAvatarUrl,
      },
      'roomId': roomId,
      'messageId': messageId,
      'threadId': threadId,
      'previewText': previewText,
      'type': type,
      'read': isRead,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
