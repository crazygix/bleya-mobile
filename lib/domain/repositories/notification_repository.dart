import '../entities/notification.dart';

abstract class NotificationRepository {
  Future<NotificationPage> fetchNotifications({int? limit, String? before});

  /// Registers this device's FCM token for the signed-in account. With
  /// [badge], iOS pushes also carry the app-icon badge count, for an app that
  /// keeps that badge current.
  Future<void> registerPushToken({
    required String token,
    required String platform,
    bool badge = false,
  });

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
