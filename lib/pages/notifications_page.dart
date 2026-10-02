import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../domain/entities/notification.dart' as app_notification;
import '../platform/app_dialog.dart';
import '../platform/app_route.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/pull_to_refresh_error_state.dart';
import '../widgets/app_spinner.dart';
import '../utils/app_errors.dart';
import '../utils/app_toast.dart';
import 'thread_view_page.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  late ProviderContainer _container;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context);
  }

  @override
  void dispose() {
    // Leaving the Activity tab marks everything read, which clears the badge
    // but keeps the items listed (only opening one dismisses it). Provider
    // state can't change while a widget is disposed, so this runs right
    // after.
    final container = _container;
    Future.microtask(() {
      try {
        final state = container.read(notificationStateProvider);
        final unreadCount = state.valueOrNull?.unreadCount ?? 0;
        if (unreadCount > 0) {
          container.read(notificationStateProvider.notifier).markAllAsRead();
        }
      } on StateError {
        // The app is shutting down with its providers; nothing to mark.
      }
    });

    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationStateProvider.notifier).loadMore();
    }
  }

  Future<void> _handleRefresh() async {
    await ref.read(notificationStateProvider.notifier).refresh();
  }

  void _markAllRead() {
    // This is the "Clean all" action - removes everything from the list
    ref.read(notificationStateProvider.notifier).dismissAll();
  }

  /// Opens [notification]'s thread, and only then dismisses the item. The
  /// loader belongs to this page rather than the item's row, which can leave
  /// the list meanwhile. Closing the loader with the back button cancels.
  Future<void> _openNotification(
    app_notification.Notification notification,
  ) async {
    final notifier = ref.read(notificationStateProvider.notifier);
    final navigator = Navigator.of(context);
    final loader = AppDialog.open(
      context: context,
      builder: (_) => const Center(child: AppSpinner(size: 24)),
    );

    try {
      final threadContext = await notifier.fetchThreadContext(
        roomId: notification.roomId,
        threadId: notification.threadId,
      );
      final stillWaiting = loader.isOnTop;
      loader.close();
      if (!stillWaiting || !mounted) return;

      unawaited(navigator.push(
        AppRoute.build(
          builder: (context) => ThreadViewPage(
            room: threadContext.room,
            parentMessage: threadContext.parentMessage,
          ),
        ),
      ));
      unawaited(notifier.dismissNotification(notification.id));
    } catch (error) {
      final stillWaiting = loader.isOnTop;
      loader.close();
      if (!stillWaiting || !mounted) return;

      if (error is AppError && error.code == AppErrorCode.notFound) {
        // Removed, or by someone blocked: the item can never open again.
        unawaited(notifier.dismissNotification(notification.id));
        AppToast.showInfo(context, 'This message is no longer available.');
        return;
      }
      AppToast.showError(
        context,
        error is AppError
            ? error.getUserMessage()
            : "Couldn't open this message. Try again?",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationStateProvider);
    final unreadCount = state.valueOrNull?.unreadCount ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent, // Handled by dashboard background
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BleyaTheme.contentPadding,
                vertical: BleyaTheme.spacingMD,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Activity',
                    style: BleyaTheme.headingMedium,
                  ),
                  if (unreadCount > 0)
                    IconButton(
                      onPressed: _markAllRead,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        CupertinoIcons.checkmark_seal,
                        color: BleyaTheme.primary,
                        size: 24,
                      ),
                    ),
                ],
              ),
            ),

            // List
            Expanded(
              child: state.when(
                data: (data) {
                  if (data.notifications.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _handleRefresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: const EmptyState(
                            icon: CupertinoIcons.sun_max,
                            title: 'Nothing new here',
                            description:
                                'Sit back and relax.\nYou\'re all caught up.',
                            iconColor: BleyaTheme.accent,
                          ),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount:
                          data.notifications.length + (data.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= data.notifications.length) {
                          return const NotificationTileSkeleton();
                        }
                        final notification = data.notifications[index];
                        return NotificationTile(
                          notification: notification,
                          onTap: () => _openNotification(notification),
                        );
                      },
                    ),
                  );
                },
                loading: () => ListView.builder(
                  padding: const EdgeInsets.only(top: BleyaTheme.spacingMD),
                  itemCount: 6,
                  itemBuilder: (_, __) => const NotificationTileSkeleton(),
                ),
                error: (_, __) => PullToRefreshErrorState(
                  title: "Couldn't load your activity",
                  description: "Let's give it another shot.",
                  onRefresh: _handleRefresh,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
