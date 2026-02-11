class Notification {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String roomId;
  final String roomName;
  final String roomType;
  final String messageId;
  final String threadId;
  final String? parentMessageText;
  final String? replyText;
  final String previewText;
  final String type; // 'reply'
  final bool isRead;
  final DateTime createdAt;

  const Notification({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.messageId,
    required this.threadId,
    this.parentMessageText,
    this.replyText,
    required this.previewText,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  Notification copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? roomId,
    String? roomName,
    String? roomType,
    String? messageId,
    String? threadId,
    String? parentMessageText,
    String? replyText,
    String? previewText,
    String? type,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Notification(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      roomType: roomType ?? this.roomType,
      messageId: messageId ?? this.messageId,
      threadId: threadId ?? this.threadId,
      parentMessageText: parentMessageText ?? this.parentMessageText,
      replyText: replyText ?? this.replyText,
      previewText: previewText ?? this.previewText,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
