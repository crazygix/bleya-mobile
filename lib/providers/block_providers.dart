import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_providers.dart';
import 'notification_provider.dart';
import 'profile_providers.dart';

/// Records that the user blocked or unblocked [userId], once the server has
/// confirmed it, so the whole app follows at once:
/// - open chats hide or show the user's messages;
/// - Activity drops their items, or loads them again after an unblock;
/// - the chat list, the blocked users and the direct chat with them load
///   again.
///
/// Every block and unblock goes through here.
void recordBlockChange(WidgetRef ref, String userId, {required bool blocked}) {
  final blockedIds = ref.read(sessionBlockedUserIdsProvider.notifier);
  final next = {...blockedIds.state};
  final changed = blocked ? next.add(userId) : next.remove(userId);
  if (changed) {
    blockedIds.state = next;
  }

  ref.invalidate(blockedUsersProvider);
  ref.invalidate(directChatStatusProvider(userId));
  unawaited(ref.read(roomsListProvider.notifier).refresh());
  unawaited(
    ref
        .read(notificationStateProvider.notifier)
        .applySenderBlockChange(userId, blocked: blocked),
  );
}
