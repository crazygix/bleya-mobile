import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/notification.dart';
import '../domain/repositories/notification_repository.dart';
import '../data/repositories/notification_repository_impl.dart';
import '../data/models/notification_model.dart';
import 'auth_providers.dart';
import 'chat_providers.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationRepositoryImpl(dio);
});

class NotificationState {
  final List<Notification> notifications;
  final int unreadCount;
  final String? nextCursor;
  final bool hasMore;

  const NotificationState({
    required this.notifications,
    required this.unreadCount,
    this.nextCursor,
    required this.hasMore,
  });

  NotificationState copyWith({
    List<Notification>? notifications,
    int? unreadCount,
    String? nextCursor,
    bool? hasMore,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class NotificationNotifier extends AsyncNotifier<NotificationState> {
  @override
  FutureOr<NotificationState> build() async {
    return _fetchPage();
  }

  Future<NotificationState> _fetchPage({String? cursor}) async {
    final repo = ref.read(notificationRepositoryProvider);
    const limit = 20;
    final page = await repo.fetchNotifications(limit: limit, before: cursor);

    return NotificationState(
      notifications: page.notifications,
      unreadCount: page.unreadCount,
      nextCursor: page.nextCursor,
      hasMore: page.nextCursor != null && page.notifications.length >= limit,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || state.isLoading) return;

    // Prevent concurrent loads
    // state = const AsyncLoading(); // Ideally we want to keep showing list while loading more
    // Riverpod's AsyncValue doesn't easily support "loading more" state without clearing data unless we handle it manually.
    // For simplicity, let's just append.

    try {
      final repo = ref.read(notificationRepositoryProvider);
      const limit = 20;
      final page = await repo.fetchNotifications(
          limit: limit, before: current.nextCursor);

      // Safeguard: only has more if we got a cursor AND we received a full page
      final hasMoreNotifications =
          page.nextCursor != null && page.notifications.length >= limit;

      state = AsyncData(current.copyWith(
        notifications: [...current.notifications, ...page.notifications],
        nextCursor: page.nextCursor,
        hasMore: hasMoreNotifications,
        // Update unread count as well from server
        unreadCount: page.unreadCount,
      ));
    } catch (e) {
      if (kDebugMode) {
        print('notifications/loadMore failed: $e');
      }
      // Keep current data on pagination errors/timeouts.
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPage());
  }

  Future<void> markAsRead(String notificationId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Update locally but stay in list
    final updatedList = current.notifications.map((n) {
      if (n.id == notificationId && !n.isRead) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    // calculate new unread count
    final wasUnread =
        current.notifications.any((n) => n.id == notificationId && !n.isRead);
    final newCount = wasUnread
        ? (current.unreadCount > 0 ? current.unreadCount - 1 : 0)
        : current.unreadCount;

    state = AsyncData(current.copyWith(
      notifications: updatedList,
      unreadCount: newCount,
    ));

    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.markAsRead(notificationId);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> markAllAsRead() async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Mark all as read but keep in list
    final updatedList =
        current.notifications.map((n) => n.copyWith(isRead: true)).toList();

    state = AsyncData(current.copyWith(
      notifications: updatedList,
      unreadCount: 0,
    ));

    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.markAllAsRead();
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> dismissNotification(String notificationId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Remove from list immediately (UX: it disappears when tapped/handled)
    final updatedList =
        current.notifications.where((n) => n.id != notificationId).toList();

    // Also update unread count if it was unread
    final wasUnread =
        current.notifications.any((n) => n.id == notificationId && !n.isRead);
    final newCount = wasUnread
        ? (current.unreadCount > 0 ? current.unreadCount - 1 : 0)
        : current.unreadCount;

    state = AsyncData(current.copyWith(
      notifications: updatedList,
      unreadCount: newCount,
    ));

    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.dismissNotification(notificationId);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> dismissAll() async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Clear everything for "Inbox Zero"
    state = AsyncData(current.copyWith(
      notifications: [],
      unreadCount: 0,
      hasMore: false,
      nextCursor: null,
    ));

    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.dismissAll();
    } catch (e) {
      // Silent fail
    }
  }

  void handleNewNotification(Notification notification) {
    final current = state.valueOrNull;
    if (current == null) return; // Not loaded yet

    final currentOpenThreadId = ref.read(currentOpenThreadIdProvider);

    // Suppression happens ONLY if the user is currently looking at this specific thread
    final isCurrentThread = currentOpenThreadId != null &&
        notification.threadId == currentOpenThreadId;

    if (isCurrentThread) {
      if (kDebugMode) {
        print(
            '🔔 Notification suppressed for active thread: ${notification.threadId}');
      }

      // Mark as read on backend since they are seeing it in real-time
      // But DO NOT add to the local notification list to keep the Alert tab clean
      try {
        final repo = ref.read(notificationRepositoryProvider);
        repo.markAsRead(notification.id);
      } catch (e) {
        // Silent fail
      }
      return;
    }

    state = AsyncData(current.copyWith(
      notifications: [notification, ...current.notifications],
      unreadCount: current.unreadCount + 1,
    ));
  }
}

final notificationStateProvider =
    AsyncNotifierProvider<NotificationNotifier, NotificationState>(
        NotificationNotifier.new);

// Socket listener as an AsyncNotifier to properly manage lifecycle
class NotificationSocketListenerNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    if (kDebugMode) {
      print('📡 NotificationSocketListener: Initializing...');
    }

    final socketService = ref.watch(socketServiceProvider);
    final notifier = ref.read(notificationStateProvider.notifier);

    if (kDebugMode) {
      print('📡 NotificationSocketListener: Ensuring socket connection...');
    }

    // Ensure socket is connected for user-level events
    await socketService.ensureConnectedForUserChannel();

    if (kDebugMode) {
      print(
          '📡 NotificationSocketListener: Socket connected, registering listener...');
    }

    // Register the listener
    socketService.onNewNotification((data) {
      if (kDebugMode) {
        print('🔔 NEW NOTIFICATION RECEIVED: $data');
      }
      try {
        final notification = NotificationModel.fromJson(data);
        if (kDebugMode) {
          print('🔔 Parsed notification: ${notification.id}');
        }
        notifier.handleNewNotification(notification);
        if (kDebugMode) {
          print('🔔 Notification added to state');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error parsing notification: $e');
        }
      }
    });

    if (kDebugMode) {
      print('✅ NotificationSocketListener: Listener registered successfully');
    }
  }
}

final notificationSocketListenerProvider =
    AsyncNotifierProvider<NotificationSocketListenerNotifier, void>(
        NotificationSocketListenerNotifier.new);
