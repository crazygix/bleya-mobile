import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_tile.dart';
import '../widgets/empty_state.dart';
import 'thread_view_page.dart';
import '../providers/repository_providers.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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
    ref.read(notificationStateProvider.notifier).markAllAsRead();
  }

  Future<void> _navigateToThread(context, notification) async {
    // 1. Mark as read immediately
    if (!notification.isRead) {
      ref.read(notificationStateProvider.notifier).markAsRead(notification.id);
    }

    // 2. Fetch data needed for ThreadViewPage
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );

    try {
      final roomRepo = ref.read(roomRepositoryProvider);
      final messageRepo = ref.read(messageRepositoryProvider);

      // Parallel fetch
      final results = await Future.wait([
        roomRepo.getRoom(notification.roomId),
        messageRepo.getMessage(notification.threadId), // Fetch parent message
      ]);

      final room = results[0]
          as dynamic; // casting needed due to Future.wait return type inference
      final parentMessage = results[1] as dynamic; // actually Message object

      if (context.mounted) {
        Navigator.pop(context); // Close loader

        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ThreadViewPage(
              room: room,
              parentMessage: parentMessage,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load thread: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationStateProvider);

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
                    'Notifications',
                    style: BleyaTheme.headingMedium,
                  ),
                  if (state.value?.unreadCount != null &&
                      state.value!.unreadCount > 0)
                    GestureDetector(
                      onTap: _markAllRead,
                      child: Text(
                        'Mark all read',
                        style: BleyaTheme.bodyMedium.copyWith(
                          color: BleyaTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
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
                            icon: CupertinoIcons.bell,
                            title: 'All caught up',
                            description: 'You have no new notifications.',
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
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $err'),
                      TextButton(
                        onPressed: _handleRefresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
