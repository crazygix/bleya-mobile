enum PushNotificationType { message, reply }

class PushNotificationPayload {
  final PushNotificationType type;
  final String roomId;
  final String messageId;
  final String senderId;
  final String? threadId;
  final String? notificationId;

  const PushNotificationPayload({
    required this.type,
    required this.roomId,
    required this.messageId,
    required this.senderId,
    this.threadId,
    this.notificationId,
  });

  bool get isReply => type == PushNotificationType.reply;
}
