import '../entities/notification.dart';

abstract class NotificationRepository {
  Future<NotificationPage> fetchNotifications({int? limit, String? before});
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
}

class NotificationPage {
  final List<Notification> notifications;
  final int unreadCount;
  final String? nextCursor;

  const NotificationPage({
    required this.notifications,
    required this.unreadCount,
    this.nextCursor,
  });
}
