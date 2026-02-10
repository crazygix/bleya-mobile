/// Domain entity for Message - pure business object, no JSON parsing
class Message {
  final String id;
  final String roomId;
  final String userId;
  final String username;
  final String text;
  final DateTime createdAt;
  final String? parentMessageId;
  final int replyCount;

  Message({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.username,
    required this.text,
    required this.createdAt,
    this.parentMessageId,
    this.replyCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
