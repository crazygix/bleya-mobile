import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's notifications on the lock screen and in the notification list
/// (Notification Center on iOS, the notification shade on Android), removed
/// through the `bleya/notifications` channel in `AppDelegate.swift` and
/// `MainActivity.kt`. Removing them leaves the iOS app-icon badge as it is.
class NotificationTrayService {
  static const _defaultChannel = MethodChannel('bleya/notifications');

  NotificationTrayService({
    bool? isSupported,
    MethodChannel channel = _defaultChannel,
  })  : isSupported = isSupported ?? (Platform.isIOS || Platform.isAndroid),
        _channel = channel;

  /// Whether this device shows the app's pushes: iPhones and Android phones.
  final bool isSupported;

  final MethodChannel _channel;

  /// Removes every notification the app has shown. Never throws: what stays
  /// is removed the next time the app comes to the foreground.
  Future<void> clearAll() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('clearAll');
    } catch (error) {
      debugPrint('notification-tray: clearing the notifications failed: $error');
    }
  }
}
