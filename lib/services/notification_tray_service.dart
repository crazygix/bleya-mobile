import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's notifications on the lock screen and in the notification list
/// (Notification Center on iOS, the notification shade on Android), through
/// the `bleya/notifications` channel in `AppDelegate.swift` and
/// `MainActivity.kt`.
///
/// It also shows pushes that arrive while the app is open as the system's
/// own banner, which takes its look (light or dark) from the phone, not from
/// the app. iOS shows the push itself and asks first ([answerBannerQuestions]);
/// on Android the app shows it ([showBanner]).
class NotificationTrayService {
  static const _defaultChannel = MethodChannel('bleya/notifications');

  NotificationTrayService({
    bool? isSupported,
    bool? showsBannersItself,
    MethodChannel channel = _defaultChannel,
  })  : isSupported = isSupported ?? (Platform.isIOS || Platform.isAndroid),
        showsBannersItself = showsBannersItself ?? Platform.isAndroid,
        _channel = channel;

  /// Whether this device shows the app's pushes: iPhones and Android phones.
  final bool isSupported;

  /// Whether the app shows the banner for a push that arrives while it is
  /// open, as on Android, where Firebase shows none then. On iOS the system
  /// shows the push itself once the app agrees.
  final bool showsBannersItself;

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

  /// Removes the notifications of one chat: [roomId]'s new messages and
  /// [threadId]'s replies. Other chats' notifications stay. Never throws.
  Future<void> clearChat({String? roomId, String? threadId}) async {
    if (!isSupported || (roomId == null && threadId == null)) return;
    try {
      await _channel.invokeMethod<void>('clearChat', {
        'roomId': roomId,
        'threadId': threadId,
      });
    } catch (error) {
      debugPrint('notification-tray: clearing the chat failed: $error');
    }
  }

  /// Shows a push that arrived while the app is open as a heads-up
  /// notification, built like the ones Firebase shows while the app is
  /// closed. It removes itself once seen, so none pile up in the shade.
  /// Tapping it opens the push as Firebase does, with [messageId]. Never
  /// throws.
  Future<void> showBanner({
    required String messageId,
    required String title,
    required String body,
    DateTime? sentTime,
  }) async {
    if (!isSupported || !showsBannersItself) return;
    try {
      await _channel.invokeMethod<void>('showBanner', {
        'messageId': messageId,
        'title': title,
        'body': body,
        if (sentTime != null) 'sentTime': sentTime.millisecondsSinceEpoch,
      });
    } catch (error) {
      debugPrint('notification-tray: showing the banner failed: $error');
    }
  }

  /// Answers iOS when a push arrives while the app is open: [shouldShow] gets
  /// the push's data and says whether iOS shows it as a banner. Null stops
  /// answering, and iOS then shows every push.
  void answerBannerQuestions(
    bool Function(Map<String, dynamic> data)? shouldShow,
  ) {
    if (!isSupported || showsBannersItself) return;
    if (shouldShow == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'shouldShowBanner') {
        throw MissingPluginException('No ${call.method} on ${_channel.name}');
      }
      final arguments = call.arguments;
      final data = arguments is Map
          ? arguments.map((key, value) => MapEntry('$key', value))
          : <String, dynamic>{};
      return shouldShow(data);
    });
  }
}
