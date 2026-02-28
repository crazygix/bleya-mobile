import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../domain/entities/notification.dart' as app_notification;
import '../providers/notification_provider.dart';
import '../widgets/notification_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/pull_to_refresh_error_state.dart';
import '../widgets/app_spinner.dart';
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
    // When leaving the Activity tab, mark everything as read to clear the badge
    // but keep them in the list (Dismissal happens only on tap)
    final state = _container.read(notificationStateProvider);
    final unreadCount = state.valueOrNull?.unreadCount ?? 0;
    if (unreadCount > 0) {
      _container.read(notificationStateProvider.notifier).markAllAsRead();
    }

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

  Future<void> _navigateToThread(
    BuildContext context,
    app_notification.Notification notification,
  ) async {
    // 1. Dismiss from the Activity list immediately
    ref
        .read(notificationStateProvider.notifier)
        .dismissNotification(notification.id);

    // 2. Fetch data needed for ThreadViewPage
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: AppSpinner(size: 24)),
    );

    try {
      final threadContext = await ref
          .read(notificationStateProvider.notifier)
          .fetchThreadContext(
            roomId: notification.roomId,
            threadId: notification.threadId,
          );

      if (context.mounted) {
        Navigator.pop(context); // Close loader

        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ThreadViewPage(
              room: threadContext.room,
              parentMessage: threadContext.parentMessage,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loader
        AppToast.showError(context, 'Failed to load thread: $e');
      }
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
                          onTap: () => _navigateToThread(context, notification),
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
                  title: "Oops, activities didn't load",
                  description: 'Pull down to try again.',
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
