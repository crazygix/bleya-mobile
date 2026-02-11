class Notification {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String roomId;
  final String messageId;
  final String threadId;
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
    required this.messageId,
    required this.threadId,
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
    String? messageId,
    String? threadId,
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
      messageId: messageId ?? this.messageId,
      threadId: threadId ?? this.threadId,
      previewText: previewText ?? this.previewText,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
