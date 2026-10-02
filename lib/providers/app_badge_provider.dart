import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'chat_providers.dart';
import 'notification_provider.dart';

/// Unread Activity items, or null while Activity loads.
final unreadActivityCountProvider = Provider<int?>((ref) {
  return ref.watch(notificationStateProvider.select(
    (activity) => activity.isLoading ? null : activity.valueOrNull?.unreadCount,
  ));
});

/// Direct chats with unread messages, or null while the chat list loads.
/// City rooms don't count, so busy rooms don't inflate the badge.
final unreadDirectChatCountProvider = Provider<int?>((ref) {
  return ref.watch(roomsListProvider.select(
    (rooms) => rooms.valueOrNull
        ?.where((item) => item.room.isPrivate && item.unreadCount > 0)
        .length,
  ));
});

/// The iOS app-icon badge: unread Activity items plus direct chats with
/// unread messages, the same count the server puts in pushes. It is 0 when
/// signed out, and null while either list loads, which leaves the badge as
/// it is.
final appBadgeCountProvider = Provider<int?>((ref) {
  final signedIn = ref.watch(
    tokenProvider.select((token) => token != null && token.isNotEmpty),
  );
  if (!signedIn) return 0;

  final activity = ref.watch(unreadActivityCountProvider);
  final directChats = ref.watch(unreadDirectChatCountProvider);
  if (activity == null || directChats == null) return null;
  return activity + directChats;
});

/// Keeps the iOS app-icon badge at [appBadgeCountProvider] while the chat
/// list is up: whenever the count changes, and again whenever the app
/// returns to the foreground, because pushes set the badge from the server's
/// count while the app was away. Signing out clears it (AuthManager). The
/// dashboard keeps it alive. It does nothing on Android, whose launchers show
/// their own notification dots.
final appBadgeProvider = Provider.autoDispose<void>((ref) {
  final badge = ref.watch(appBadgeServiceProvider);
  if (!badge.isSupported) return;

  void show(int? count) {
    if (count != null) {
      unawaited(badge.setBadgeCount(count));
    }
  }

  ref.listen<int?>(
    appBadgeCountProvider,
    (_, count) => show(count),
    fireImmediately: true,
  );
  final lifecycle = AppLifecycleListener(
    onResume: () => show(ref.read(appBadgeCountProvider)),
  );
  ref.onDispose(lifecycle.dispose);
});
