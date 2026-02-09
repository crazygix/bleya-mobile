import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
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

  void _onTabChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _onTabChanged(0),
                            child: Container(
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: _selectedIndex == 0
                                    ? CupertinoColors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: _selectedIndex == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.chat_bubble,
                                    color: _selectedIndex == 0
                                        ? BleyaTheme.primary
                                        : BleyaTheme.mutedForeground
                                            .withValues(alpha: 0.4),
                                    size: 24,
                                  ),
                                  if (_selectedIndex == 0)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top: BleyaTheme.spacingXS),
                                      child: Text(
                                        'Chats',
                                        style: BleyaTheme.bodySmall.copyWith(
                                          color: BleyaTheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _onTabChanged(1),
                            child: Container(
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: _selectedIndex == 1
                                    ? CupertinoColors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: _selectedIndex == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.settings,
                                    color: _selectedIndex == 1
                                        ? BleyaTheme.primary
                                        : BleyaTheme.mutedForeground
                                            .withValues(alpha: 0.4),
                                    size: 24,
                                  ),
                                  if (_selectedIndex == 1)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top: BleyaTheme.spacingXS),
                                      child: Text(
                                        'Settings',
                                        style: BleyaTheme.bodySmall.copyWith(
                                          color: BleyaTheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
    final joinedRoomsAsync = ref.watch(joinedRoomsFutureProvider);
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;

    return joinedRoomsAsync.when(
      data: (rooms) {
        if (rooms.isEmpty) {
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
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            final isPrivate = room.isPrivate;
            final hasLastMessage = room.lastMessageText != null;

            String subtitle;
            if (hasLastMessage) {
              String prefix = '';
              if (!isPrivate && room.lastMessageUserId != null) {
                final isCurrentUser = room.lastMessageUserId == currentUserId;
                prefix = isCurrentUser ? 'You: ' : '${room.lastMessageUsername ?? 'Unknown'}: ';
              }
              subtitle = '$prefix${room.lastMessageText}';
            } else {
              subtitle = isPrivate ? 'Private chat' : 'Tap to join the conversation';
            }

            final time = room.lastMessageTime != null
                ? formatRelativeTime(room.lastMessageTime!)
                : 'Now';

            return RoomCard(
              room: room,
              subtitle: subtitle,
              time: time,
              unreadCount: 0,
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
      loading: () => Center(
        child: CupertinoActivityIndicator(),
      ),
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
}
