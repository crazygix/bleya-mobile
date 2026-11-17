import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A short message for the user, shown with the system's own elements rather
/// than drawn by the app, so it takes the phone's look (light or dark), not
/// the app's. Push notifications are separate (`inAppBannersProvider`).
///
/// - Android shows both kinds as a system toast (`MainActivity.kt`).
/// - iOS has no toast (`AppDelegate.swift`): a notice is a system alert with
///   OK, and a confirmation is a small pill near the top of the screen, made
///   from the system's own materials and fonts.
class SystemMessage {
  SystemMessage._();

  static const _channel = MethodChannel('bleya/messages');

  /// Something the user must see: an error ("Couldn't open the link.") or a
  /// notice ("This message was removed."). Never throws.
  static void showNotice(String message) => _show(message, 'notice');

  /// That what the user just did worked ("Passkey added."). Never throws.
  static void showConfirmation(String message) =>
      _show(message, 'confirmation');

  static void _show(String message, String kind) {
    final text = message.trim();
    if (text.isEmpty) return;
    unawaited(_send(text, kind));
  }

  static Future<void> _send(String text, String kind) async {
    try {
      await _channel.invokeMethod<void>('show', {
        'message': text,
        'kind': kind,
      });
    } catch (error) {
      debugPrint('system-message: showing "$text" failed: $error');
    }
  }
}
