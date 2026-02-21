import '../../domain/entities/direct_chat_status.dart';

class DirectChatDto {
  static bool _parseBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    if (value is num) return value != 0;
    return fallback;
  }

  static DirectChatStatus statusFromJson(Map<String, dynamic> json) {
    final hasChat = _parseBool(json['hasChat']);
    final isBlockedByMe = _parseBool(json['isBlockedByMe']);
    final isBlockedByOtherUser = _parseBool(json['isBlockedByOtherUser']);
    final canSendMessage = _parseBool(
      json['canSendMessage'],
      fallback: !(isBlockedByMe || isBlockedByOtherUser),
    );
    final isDeletedByMe = _parseBool(json['isDeletedByMe']);

    return DirectChatStatus(
      hasChat: hasChat,
      roomId: json['roomId'] as String?,
      isBlockedByMe: isBlockedByMe,
      isBlockedByOtherUser: isBlockedByOtherUser,
      canSendMessage: canSendMessage,
      isDeletedByMe: isDeletedByMe,
    );
  }

  static DirectChatActionResult actionFromJson(Map<String, dynamic> json) {
    return DirectChatActionResult(
      message: json['message'] as String? ?? 'Done',
      roomId: json['roomId'] as String?,
      hasChat: _parseBool(json['hasChat']),
      blocked: _parseBool(json['blocked']),
      deleted: _parseBool(json['deleted']),
      alreadyBlocked: _parseBool(json['alreadyBlocked']),
    );
  }
}
