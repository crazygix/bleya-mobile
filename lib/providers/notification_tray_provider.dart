import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

/// Removes the app's notifications from the lock screen and the notification
/// list whenever the app opens or comes back to the foreground, signed in or
/// out, so opening one of five notifications doesn't leave the other four
/// behind. Nothing unread is lost: the chat list, Activity and the iOS
/// app-icon badge still count it. Pushes that arrive while the app is in the
/// foreground show no notification, so none pile up meanwhile. MyApp keeps
/// it alive.
final notificationTrayClearingProvider = Provider<void>((ref) {
  final tray = ref.watch(notificationTrayServiceProvider);
  if (!tray.isSupported) return;

  void clear() => unawaited(tray.clearAll());

  // Already in the foreground: the listener only reports later returns.
  if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
    clear();
  }
  final lifecycle = AppLifecycleListener(onResume: clear);
  ref.onDispose(lifecycle.dispose);
});
