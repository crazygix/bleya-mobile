import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The number on the iOS app icon, set through the `bleya/badge` channel in
/// `AppDelegate.swift`. While the chat list is up the app keeps it equal to
/// its unread counts; while the app is away, pushes carry the server's count.
/// Android launchers show their own notification dots, so it does nothing
/// there.
class AppBadgeService {
  /// Counts stop at 99, as in the server's pushes, so the two always agree.
  static const maxCount = 99;

  static const _defaultChannel = MethodChannel('bleya/badge');

  AppBadgeService({
    bool? isSupported,
    MethodChannel channel = _defaultChannel,
  })  : isSupported = isSupported ?? Platform.isIOS,
        _channel = channel;

  /// Whether this device has an app-icon badge to keep: iPhones only.
  final bool isSupported;

  final MethodChannel _channel;

  /// Shows [count] on the app icon, or no badge for 0. Never throws: the
  /// badge is a hint, and the next change or return to the app sets it again.
  Future<void> setBadgeCount(int count) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(
        'setBadgeCount',
        count.clamp(0, maxCount),
      );
    } catch (error) {
      debugPrint('app-badge: setting the badge failed: $error');
    }
  }
}
