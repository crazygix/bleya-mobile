class DirectChatStatus {
  final bool hasChat;
  final String? roomId;
  final bool isBlockedByMe;
  final bool isBlockedByOtherUser;
  final bool canSendMessage;
  final bool isDeletedByMe;

  const DirectChatStatus({
    required this.hasChat,
    required this.roomId,
    required this.isBlockedByMe,
    required this.isBlockedByOtherUser,
    required this.canSendMessage,
    required this.isDeletedByMe,
  });

  bool get isBlocked => isBlockedByMe || isBlockedByOtherUser;
}

class DirectChatActionResult {
  final String message;
  final String? roomId;
  final bool hasChat;
  final bool blocked;
  final bool deleted;
  final bool alreadyBlocked;

  const DirectChatActionResult({
    required this.message,
    required this.roomId,
    required this.hasChat,
    required this.blocked,
    required this.deleted,
    required this.alreadyBlocked,
  });
}
