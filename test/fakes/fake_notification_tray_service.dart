import 'package:bleya/services/notification_tray_service.dart';

/// Counts how often the app clears its notifications from the lock screen,
/// instead of clearing them. [isSupported] tells the app whether the device
/// gets pushes.
class FakeNotificationTrayService extends NotificationTrayService {
  FakeNotificationTrayService({bool isSupported = true})
      : super(isSupported: isSupported);

  int clears = 0;

  @override
  Future<void> clearAll() async {
    clears++;
  }
}
