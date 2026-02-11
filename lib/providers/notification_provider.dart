import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/notification.dart';
import '../domain/repositories/notification_repository.dart';
import '../data/repositories/notification_repository_impl.dart';
import '../data/models/notification_model.dart';
import 'auth_providers.dart';

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
    final page = await repo.fetchNotifications(limit: 20, before: cursor);

    return NotificationState(
      notifications: page.notifications,
      unreadCount: page.unreadCount,
      nextCursor: page.nextCursor,
      hasMore: page.nextCursor != null,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || state.isLoading) return;

    // Prevent concurrent loads
    // state = const AsyncLoading(); // Ideally we want to keep showing list while loading more
    // Riverpod's AsyncValue doesn't easily support "loading more" state without clearing data unless we handle it manually.
    // For simplicity, let's just append.

    try {
      final repo = ref.read(notificationRepositoryProvider);
      final page =
          await repo.fetchNotifications(limit: 20, before: current.nextCursor);

      // If page returns no new notifications, set hasMore to false
      final hasMoreNotifications =
          page.nextCursor != null && page.notifications.isNotEmpty;

      state = AsyncData(current.copyWith(
        notifications: [...current.notifications, ...page.notifications],
        nextCursor: page.nextCursor,
        hasMore: hasMoreNotifications,
        // Update unread count as well from server
        unreadCount: page.unreadCount,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPage());
  }

  Future<void> markAsRead(String notificationId) async {
    final current = state.value;
    if (current == null) return;

    // Optimistic update
    final updatedList = current.notifications.map((n) {
      if (n.id == notificationId && !n.isRead) {
        return (n as NotificationModel).copyWith(
            isRead:
                true); // Cast to access copyWith if needed, or Entity should have it
        // Entity has copyWith.
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
      // Revert if failed? Or silent fail. Silent fail is usually okay for read receipt.
    }
  }

  Future<void> markAllAsRead() async {
    final current = state.value;
    if (current == null) return;

    // Optimistic
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

  void handleNewNotification(Notification notification) {
    final current = state.value;
    if (current == null) return; // Not loaded yet

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
