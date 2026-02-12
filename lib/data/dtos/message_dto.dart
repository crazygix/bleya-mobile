import '../../domain/entities/message.dart';

/// Data Transfer Object for Message - handles JSON parsing.
class MessageDto {
  static Message fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      json['createdAt'] as int,
    );

    return Message(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String? ?? '',
      text: json['text'] as String,
      createdAt: createdAt,
      parentMessageId: json['parentMessageId'] as String?,
      replyCount: json['replyCount'] as int? ?? 0,
    );
  }
}
