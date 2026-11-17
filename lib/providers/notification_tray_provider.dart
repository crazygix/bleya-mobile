import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/push_notification_payload.dart';
import '../services/push_messaging_service.dart';
import '../services/socket_service.dart';
import 'auth_providers.dart';

/// Removes the notifications of the chat on screen from the lock screen and
/// the notification list: a room's messages when its screen opens, a
/// thread's replies when its screen opens, and the open chat's again
/// whenever the app comes back to the foreground, as pushes arrive for it
/// while the app is away. Other chats' notifications stay until their chat
/// opens, so none go missing. The dashboard keeps it alive.
final openChatNotificationsClearingProvider = Provider<void>((ref) {
  final tray = ref.watch(notificationTrayServiceProvider);
  if (!tray.isSupported) return;
  final socket = ref.read(socketServiceProvider);

  void clearOpenChat() {
    final openChat = socket.openChat.value;
    unawaited(
      tray.clearChat(roomId: openChat.roomId, threadId: openChat.threadId),
    );
  }

  clearOpenChat();
  socket.openChat.addListener(clearOpenChat);
  final lifecycle = AppLifecycleListener(onResume: clearOpenChat);
  ref.onDispose(() {
    socket.openChat.removeListener(clearOpenChat);
    lifecycle.dispose();
  });
});

/// Whether [payload] is for the chat [openChat] already shows, which shows
/// the new message by itself: a message for that room with no thread open,
/// or a reply in that thread. The same check as `isPushForOpenChat`.
bool isPayloadForOpenChat(PushNotificationPayload payload, OpenChat openChat) {
  if (payload.isReply) {
    return payload.threadId != null && openChat.threadId == payload.threadId;
  }
  return openChat.roomId == payload.roomId && openChat.threadId == null;
}

/// Shows pushes that arrive while the app is open as the system's own
/// banner, as the phone shows them while the app is closed, in the phone's
/// light or dark look. None shows for the chat on screen, nor while signed
/// out. The server sends no push for the chat a user is in, but one may
/// arrive while the socket reconnects after the app comes back.
///
/// iOS shows the push itself after asking; on Android, where Firebase shows
/// nothing while the app is open, the app shows it. A tap opens the chat as
/// a tap on any push does. MyApp keeps it alive.
final inAppBannersProvider = Provider<void>((ref) {
  final tray = ref.watch(notificationTrayServiceProvider);
  if (!tray.isSupported) return;

  final socket = ref.watch(socketServiceProvider);

  bool shouldShow(PushNotificationPayload payload) {
    final token = ref.read(tokenProvider);
    if (token == null || token.isEmpty) return false;
    return !isPayloadForOpenChat(payload, socket.openChat.value);
  }

  if (tray.showsBannersItself) {
    final subscription = ref
        .watch(pushMessagingServiceProvider)
        .onForegroundMessage
        .listen((push) {
      if (!shouldShow(push.payload)) return;
      unawaited(tray.showBanner(
        messageId: push.messageId,
        title: push.title,
        body: push.body,
        sentTime: push.sentTime,
      ));
    });
    ref.onDispose(subscription.cancel);
    return;
  }

  tray.answerBannerQuestions((data) {
    final payload = PushMessagingService.payloadOf(data);
    // Not one of the app's pushes: iOS shows it as it would any other.
    if (payload == null) {
      final token = ref.read(tokenProvider);
      return token != null && token.isNotEmpty;
    }
    return shouldShow(payload);
  });
  ref.onDispose(() => tray.answerBannerQuestions(null));
});
