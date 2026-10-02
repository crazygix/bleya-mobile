import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/notification.dart';
import '../use_cases/notification/get_notification_thread_context_use_case.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import 'use_case_providers.dart';

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

/// A local change to Activity, such as a new notification or a dismissal.
typedef _NotificationChange = NotificationState Function(NotificationState);

class NotificationNotifier extends AsyncNotifier<NotificationState> {
  /// Changes whenever the session changes (this notifier is rebuilt) or it is
  /// disposed, so a page requested earlier can tell it arrived too late.
  int _sessionGeneration = 0;

  /// Changes whenever a refresh replaces the list, so a next page requested
  /// before it is dropped.
  int _listGeneration = 0;

  // The last refresh asked for this session; the next one waits for it.
  Future<void>? _lastRefresh;

  // Local changes made while a refresh fetches, applied to its page too: the
  // server may have answered before it saw them.
  List<_NotificationChange>? _changesDuringRefresh;

  bool get _isRefreshing => _changesDuringRefresh != null;

  @override
  FutureOr<NotificationState> build() async {
    // Runs as soon as sessionVersionProvider changes, even when the rebuild
    // itself waits for the next frame.
    ref.onDispose(() {
      _sessionGeneration++;
      // The next session's refreshes don't wait for this one's.
      _lastRefresh = null;
      _changesDuringRefresh = null;
    });
    ref.watch(sessionVersionProvider);
    final token = ref.read(tokenProvider);
    if (token == null || token.isEmpty) {
      return const NotificationState(
        notifications: [],
        unreadCount: 0,
        nextCursor: null,
        hasMore: false,
      );
    }

    try {
      return await _fetchPage();
    } catch (_) {
      // Load again once the socket connects, e.g. after an offline start.
      ref.read(socketServiceProvider).requestResyncOnConnect();
      rethrow;
    }
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
    // A refresh is about to replace the list; scrolling again after it loads
    // more.
    if (current == null ||
        !current.hasMore ||
        state.isLoading ||
        _isRefreshing) {
      return;
    }

    // Prevent concurrent loads
    // state = const AsyncLoading(); // Ideally we want to keep showing list while loading more
    // Riverpod's AsyncValue doesn't easily support "loading more" state without clearing data unless we handle it manually.
    // For simplicity, let's just append.

    final session = _sessionGeneration;
    final list = _listGeneration;
    try {
      final repo = ref.read(notificationRepositoryProvider);
      const limit = 20;
      final page = await repo.fetchNotifications(
          limit: limit, before: current.nextCursor);
      // Signed out or switched accounts meanwhile: the page belongs to the
      // previous session.
      if (session != _sessionGeneration) return;
      // A refresh replaced the list meanwhile: this page follows the old one.
      if (list != _listGeneration) return;

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

  /// Fetches the first page again. A [silent] refresh keeps the list on
  /// screen while it loads and when it fails, for catching up in the
  /// background; otherwise the list shows loading, as on a pull to refresh.
  /// Calls run one after another, and new notifications and other changes
  /// made meanwhile are kept.
  Future<void> refresh({bool silent = false}) {
    final session = _sessionGeneration;
    final previous = _lastRefresh;
    final run = previous == null
        ? _refreshOnce(session, silent: silent)
        : previous.then((_) => _refreshOnce(session, silent: silent));
    // The next refresh waits for this one, whether or not it succeeds.
    final done = run.then<void>((_) {}, onError: (Object _) {});
    _lastRefresh = done;
    unawaited(done.then((_) {
      if (identical(_lastRefresh, done)) {
        _lastRefresh = null;
      }
    }));
    return run;
  }

  Future<void> _refreshOnce(int session, {required bool silent}) async {
    // Signed out or switched accounts while it waited for the previous one.
    if (session != _sessionGeneration) return;
    if (!silent) {
      state = const AsyncLoading();
    }

    final changes = <_NotificationChange>[];
    _changesDuringRefresh = changes;
    final result = await AsyncValue.guard(() => _fetchPage());
    if (identical(_changesDuringRefresh, changes)) {
      _changesDuringRefresh = null;
    }
    // Signed out or switched accounts meanwhile: the page belongs to the
    // previous session.
    if (session != _sessionGeneration) return;

    if (result case AsyncData(:final value)) {
      _listGeneration++;
      state = AsyncData(changes.fold(value, (page, change) => change(page)));
    } else if (!silent || !state.hasValue) {
      state = result;
    }
    // A silent refresh that failed keeps the list on screen.
  }

  /// Applies [change] to the list on screen, and to the page a refresh is
  /// fetching, which may predate it.
  void _apply(_NotificationChange change) {
    _changesDuringRefresh?.add(change);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(change(current));
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (state.valueOrNull == null) return;

    // Update locally but stay in list
    _apply((current) {
      final wasUnread =
          current.notifications.any((n) => n.id == notificationId && !n.isRead);
      if (!wasUnread) return current;
      return current.copyWith(
        notifications: [
          for (final n in current.notifications)
            n.id == notificationId ? n.copyWith(isRead: true) : n,
        ],
        unreadCount: current.unreadCount > 0 ? current.unreadCount - 1 : 0,
      );
    });

    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.markAsRead(notificationId);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> markAllAsRead() async {
    if (state.valueOrNull == null) return;

    // Mark all as read but keep in list
    _apply((current) => current.copyWith(
          notifications: [
            for (final n in current.notifications) n.copyWith(isRead: true),
          ],
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
    if (state.valueOrNull == null) return;

    // Remove from list immediately (UX: it disappears when tapped/handled),
    // and lower the unread count if it was unread.
    _apply((current) {
      final wasUnread =
          current.notifications.any((n) => n.id == notificationId && !n.isRead);
      return current.copyWith(
        notifications:
            current.notifications.where((n) => n.id != notificationId).toList(),
        unreadCount: wasUnread && current.unreadCount > 0
            ? current.unreadCount - 1
            : current.unreadCount,
      );
    });

    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.dismissNotification(notificationId);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> dismissAll() async {
    if (state.valueOrNull == null) return;

    // Clear everything for "Inbox Zero"
    _apply((current) => current.copyWith(
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

  Future<NotificationThreadContext> fetchThreadContext({
    required String roomId,
    required String threadId,
  }) async {
    final useCase = ref.read(getNotificationThreadContextUseCaseProvider);
    return await useCase(roomId: roomId, threadId: threadId);
  }

  void handleNewNotification(Notification notification) {
    // Not loaded yet, and no refresh to keep it for.
    if (state.valueOrNull == null && !_isRefreshing) return;

    final openThreadId =
        ref.read(socketServiceProvider).openChat.value.threadId;

    // Suppression happens ONLY if the user is currently looking at this specific thread
    final isCurrentThread =
        openThreadId != null && notification.threadId == openThreadId;

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

    _apply((current) {
      // Already listed, e.g. on a page fetched after it arrived.
      if (current.notifications.any((n) => n.id == notification.id)) {
        return current;
      }
      return current.copyWith(
        notifications: [notification, ...current.notifications],
        unreadCount: current.unreadCount + 1,
      );
    });
  }
}

final notificationStateProvider =
    AsyncNotifierProvider<NotificationNotifier, NotificationState>(
        NotificationNotifier.new);

// Socket listener as an AsyncNotifier to properly manage lifecycle
class NotificationSocketListenerNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    ref.watch(sessionVersionProvider);
    final token = ref.read(tokenProvider);
    if (token == null || token.isEmpty) {
      return;
    }

    if (kDebugMode) {
      print('📡 NotificationSocketListener: Initializing...');
    }

    final socketService = ref.watch(socketServiceProvider);
    final notifier = ref.read(notificationStateProvider.notifier);

    // A session change or dispose ends this listener. It then removes its
    // handler, or registers none if it's still connecting.
    var superseded = false;
    dynamic handler;
    // Notifications sent while the socket was away never arrive, so Activity
    // catches up whenever the socket asks, keeping the list on screen. This
    // listens before connecting, so the first connect's request isn't missed.
    final resyncSubscription = socketService.resyncRequests.listen((_) {
      unawaited(notifier.refresh(silent: true));
    });
    ref.onDispose(() {
      superseded = true;
      resyncSubscription.cancel();
      if (handler != null) {
        socketService.removeListener('new_notification', handler);
      }
    });

    if (kDebugMode) {
      print('📡 NotificationSocketListener: Ensuring socket connection...');
    }

    // Ensure socket is connected for user-level events
    await socketService.ensureConnectedForUserChannel();
    if (superseded) {
      if (kDebugMode) {
        print('📡 NotificationSocketListener: Session changed, not listening');
      }
      return;
    }

    if (kDebugMode) {
      print(
          '📡 NotificationSocketListener: Socket connected, registering listener...');
    }

    // Register the listener
    handler = socketService.onNewNotificationEntity((notification) {
      if (kDebugMode) {
        print('🔔 NEW NOTIFICATION RECEIVED: ${notification.id}');
      }
      notifier.handleNewNotification(notification);
      if (kDebugMode) {
        print('🔔 Notification added to state');
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
