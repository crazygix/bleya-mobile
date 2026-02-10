import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/room_card.dart';
import '../widgets/empty_state.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../utils/app_errors.dart';
import '../utils/time_formatter.dart';
import 'chat_room_page.dart';
import 'settings_page.dart';
import 'join_room_dialog.dart';

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
    showCupertinoModalPopup(
      context: context,
      builder: (context) => JoinRoomDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;

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
                        GestureDetector(
                          onTap: _showJoinRoomDialog,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: BleyaTheme.glassSurface
                                  .withValues(alpha: BleyaTheme.glassOpacity),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: BleyaTheme.border,
                                width: 1,
                              ),
                              boxShadow: BleyaTheme.glassShadow,
                            ),
                            child: Icon(
                              CupertinoIcons.add,
                              color: BleyaTheme.primary,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Main Content
                Expanded(
                  child: _selectedIndex == 0 ? _buildChatTab() : SettingsPage(),
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
                                  : Alignment.centerRight,
                              child: FractionallySizedBox(
                                widthFactor: 0.5,
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
                                        offset: Offset(0, 2),
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
                                  label: 'Chats',
                                ),
                                _buildBottomNavItem(
                                  index: 1,
                                  icon: CupertinoIcons.settings,
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

  Widget _buildChatTab() {
    final roomsAsync = ref.watch(roomsListProvider);
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;

    return roomsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: CupertinoIcons.airplane,
            title: 'Ready for takeoff?',
            description:
                'Your next adventure is just a chat away. Connect with travelers now.',
            actionText: 'Join a room',
            onAction: _showJoinRoomDialog,
          );
        }

        return ListView.builder(
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
        );
      },
      loading: _buildRoomsSkeleton,
      error: (error, stack) {
        String errorMessage;
        if (error is AppError) {
          errorMessage = error.getUserMessage();
        } else {
          errorMessage = "Couldn't load your rooms. Pull down to refresh.";
        }
        return Center(
          child: Padding(
            padding: EdgeInsets.all(BleyaTheme.spacing2XL),
            child: Text(
              errorMessage,
              style: BleyaTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
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
    required String label,
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
              Icon(
                icon,
                color: isSelected
                    ? BleyaTheme.primary
                    : BleyaTheme.mutedForeground.withValues(alpha: 0.4),
                size: 24,
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
