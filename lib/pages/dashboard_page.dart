import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/room_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_circle_icon_button.dart';
import '../widgets/pull_to_refresh_error_state.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../utils/time_formatter.dart';
import 'chat_room_page.dart';
import 'settings_page.dart';
import 'join_room_dialog.dart';
import 'notifications_page.dart';
import '../providers/notification_provider.dart';

/// Dashboard Page
///
/// Main entry point of the app with bottom navigation between Chat and Settings tabs.
/// Features iOS-style navigation with glassmorphism and liquid background.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _selectedIndex = 0;
  static const Duration _tabSwitchDuration = Duration(milliseconds: 260);

  void _onTabChanged(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      // When switching back to the Chats tab, clear any "open room" marker
      // after the current build frame finishes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentOpenRoomIdProvider.notifier).state = null;
      });
    }
  }

  void _showJoinRoomDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const JoinRoomDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;

    // Keep notification socket listener alive
    ref.watch(notificationSocketListenerProvider);

    return Scaffold(
      backgroundColor: BleyaTheme.background,
      body: Stack(
        children: [
          const LiquidGlassBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header (only shown on Chat tab)
                if (_selectedIndex == 0)
                  Padding(
                    padding: EdgeInsets.only(
                      left: BleyaTheme.contentPadding,
                      right: BleyaTheme.contentPadding,
                      top: BleyaTheme.spacingMD,
                      bottom: BleyaTheme.spacingLG,
                    ),
                    child: Row(
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Bleya',
                                style: BleyaTheme.headingMedium
                                    .copyWith(fontSize: 34),
                              ),
                              TextSpan(
                                text: '.',
                                style: BleyaTheme.headingMedium.copyWith(
                                  fontSize: 34,
                                  color: BleyaTheme.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Spacer(),
                        GlassCircleIconButton(
                          icon: CupertinoIcons.add,
                          onPressed: _showJoinRoomDialog,
                          semanticLabel: 'Open city rooms',
                        ),
                      ],
                    ),
                  ),
                // Main Content
                Expanded(
                  child: _selectedIndex == 0
                      ? _buildChatTab()
                      : _selectedIndex == 1
                          ? const NotificationsPage()
                          : SettingsPage(),
                ),
                // Bottom Navigation
                Container(
                  padding: EdgeInsets.only(
                    left: BleyaTheme.contentPadding,
                    right: BleyaTheme.contentPadding,
                    top: BleyaTheme.spacingMD,
                    bottom: padding.bottom + BleyaTheme.spacingMD,
                  ),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: BleyaTheme.glassSurface
                          .withValues(alpha: BleyaTheme.glassOpacity),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: BleyaTheme.border,
                        width: 1,
                      ),
                      boxShadow: BleyaTheme.glassShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Stack(
                          children: [
                            AnimatedAlign(
                              duration: _tabSwitchDuration,
                              curve: Curves.easeInOutCubic,
                              alignment: _selectedIndex == 0
                                  ? Alignment.centerLeft
                                  : _selectedIndex == 1
                                      ? Alignment.center
                                      : Alignment.centerRight,
                              child: FractionallySizedBox(
                                widthFactor: 0.333,
                                heightFactor: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.white,
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                _buildBottomNavItem(
                                  index: 0,
                                  icon: CupertinoIcons.chat_bubble,
                                  selectedIcon: CupertinoIcons.chat_bubble_fill,
                                  label: 'Chats',
                                ),
                                _buildBottomNavItem(
                                  index: 1,
                                  icon: CupertinoIcons.bell,
                                  selectedIcon: CupertinoIcons.bell_fill,
                                  label: 'Activity',
                                  showBadge: true,
                                ),
                                _buildBottomNavItem(
                                  index: 2,
                                  icon: CupertinoIcons.settings,
                                  selectedIcon: CupertinoIcons.settings_solid,
                                  label: 'Settings',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await ref.read(roomsListProvider.notifier).refresh();
  }

  Widget _buildChatTab() {
    final roomsAsync = ref.watch(roomsListProvider);
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;

    return roomsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: EmptyState(
                  icon: CupertinoIcons.sparkles,
                  title: 'Find your crowd',
                  description:
                      'No chats here yet.\nReady to find your next hangout?',
                  iconColor: BleyaTheme.accent,
                  actionText: 'Join a room',
                  onAction: _showJoinRoomDialog,
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: BleyaTheme.contentPadding,
            ).copyWith(
              bottom: 100,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final room = item.room;
              final isPrivate = room.isPrivate;
              final hasLastMessage = room.lastMessageText != null;

              String subtitle;
              if (hasLastMessage) {
                String prefix = '';
                if (!isPrivate && room.lastMessageUserId != null) {
                  final isCurrentUser = room.lastMessageUserId == currentUserId;
                  prefix = isCurrentUser
                      ? 'You: '
                      : '${room.lastMessageUsername ?? 'Unknown'}: ';
                }
                subtitle = '$prefix${room.lastMessageText}';
              } else {
                subtitle =
                    isPrivate ? 'Private chat' : 'Tap to join the conversation';
              }

              final time = room.lastMessageTime != null
                  ? formatRelativeTime(room.lastMessageTime!)
                  : 'Now';

              return RoomCard(
                room: room,
                subtitle: subtitle,
                time: time,
                unreadCount: item.unreadCount,
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => ChatRoomPage(room: room),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
      loading: _buildRoomsSkeleton,
      error: (_, __) => PullToRefreshErrorState(
        title: "Oops, chats didn't load",
        description: 'Pull down to try again.',
        onRefresh: _handleRefresh,
      ),
    );
  }

  Widget _buildRoomsSkeleton() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: BleyaTheme.contentPadding,
      ).copyWith(
        bottom: 100,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: BleyaTheme.spacingSM),
          child: Container(
            padding: const EdgeInsets.all(BleyaTheme.radiusSmall),
            decoration: BoxDecoration(
              color: BleyaTheme.glassSurface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
              border: Border.all(
                color: BleyaTheme.border.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: BleyaTheme.glassShadow,
            ),
            child: Row(
              children: [
                const AppSkeleton.circle(size: 48),
                const SizedBox(width: BleyaTheme.spacingMD),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppSkeleton(
                              height: 16,
                            ),
                          ),
                          SizedBox(width: BleyaTheme.spacingSM),
                          AppSkeleton(
                            width: 40,
                            height: 12,
                          ),
                        ],
                      ),
                      SizedBox(height: BleyaTheme.spacingXS),
                      AppSkeleton(
                        width: 180,
                        height: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    bool showBadge = false,
  }) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabChanged(index),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? selectedIcon : icon,
                    color: isSelected
                        ? BleyaTheme.primary
                        : BleyaTheme.mutedForeground.withValues(alpha: 0.4),
                    size: 24,
                  ),
                  if (showBadge && index == 1)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Consumer(
                        builder: (context, ref, _) {
                          final unreadCount = ref.watch(
                            notificationStateProvider.select(
                              (state) => state.valueOrNull?.unreadCount ?? 0,
                            ),
                          );
                          if (unreadCount == 0) return const SizedBox.shrink();

                          return Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              AnimatedSize(
                duration: _tabSwitchDuration,
                curve: Curves.easeInOutCubic,
                child: isSelected
                    ? Padding(
                        padding: EdgeInsets.only(top: BleyaTheme.spacingXS),
                        child: Text(
                          label,
                          style: BleyaTheme.bodySmall.copyWith(
                            color: BleyaTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
