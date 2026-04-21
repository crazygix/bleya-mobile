import '../entities/notification.dart';

abstract class NotificationRepository {
  Future<NotificationPage> fetchNotifications({int? limit, String? before});
  Future<void> registerPushToken({
    required String token,
    required String platform,
  });
  Future<void> unregisterPushToken({required String token});
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> dismissNotification(String notificationId);
  Future<void> dismissAll();
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
