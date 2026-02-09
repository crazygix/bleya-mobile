import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../utils/app_errors.dart';
import '../constants/theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/danger_button.dart';
import '../widgets/error_state.dart';
import '../widgets/glass_header.dart';
import '../widgets/liquid_glass_background.dart';
import 'user_details_page.dart';

class RoomDetailsPage extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;

  const RoomDetailsPage({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  ConsumerState<RoomDetailsPage> createState() => _RoomDetailsPageState();
}

class _RoomDetailsPageState extends ConsumerState<RoomDetailsPage> {
  @override
  void initState() {
    super.initState();
    // Invalidate and refresh room members when page is opened to get latest data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(roomMembersProvider(widget.roomId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(roomMembersProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;

    return Scaffold(
      backgroundColor: BleyaTheme.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const LiquidGlassBackground(),
          Column(
            children: [
              GlassHeader(
                leftAction: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.chevron_left,
                        size: 28,
                        color: BleyaTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 17,
                          color: BleyaTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                title: widget.roomName,
              ),
              Expanded(
                child: membersAsync.when(
                  data: (members) {
                    if (members.isEmpty) {
                      return Center(
                        child: Text(
                          'No members in this room',
                          style: TextStyle(
                            fontSize: 16,
                            color: BleyaTheme.mutedForeground,
                          ),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                BleyaTheme.primary.withValues(alpha: 0.8),
                                BleyaTheme.secondary.withValues(alpha: 0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    BleyaTheme.primary.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.3),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.roomName,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${members.length} Members in Group',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        DangerButton(
                          text: 'Leave Room',
                          onPressed: () async {
                            final confirmed = await showCupertinoDialog<bool>(
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: const Text('Leave Room'),
                                content: const Text(
                                    'Are you sure you want to leave this room?'),
                                actions: [
                                  CupertinoDialogAction(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  CupertinoDialogAction(
                                    isDestructiveAction: true,
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Leave'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              try {
                                await leaveRoom(ref, widget.roomId);
                                if (context.mounted) {
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    '/home',
                                    ModalRoute.withName('/'),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  String errorMessage;
                                  if (e is AppError) {
                                    errorMessage = e.getUserMessage();
                                  } else {
                                    errorMessage =
                                        "Couldn't leave that room. Try again?";
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(errorMessage)),
                                  );
                                }
                              }
                            }
                          },
                          trailingIcon: Icon(
                            CupertinoIcons.arrow_right_square,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              'Members',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: BleyaTheme.foreground,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${members.length})',
                              style: TextStyle(
                                fontSize: 18,
                                color: BleyaTheme.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...members.map((member) {
                          final displayName = member.username.isNotEmpty
                              ? member.username
                              : member.phoneNumber;
                          final isCurrentUser = currentUserId != null &&
                              member.id == currentUserId;

                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => UserDetailsPage(
                                    userId: member.id,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: BleyaTheme.glassSurface
                                    .withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      BleyaTheme.border.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      ProfileAvatar(
                                        imageUrl: member.profileImageUrl,
                                        size: 48,
                                        backgroundColor: BleyaTheme.greyLight,
                                        fallbackIcon:
                                            CupertinoIcons.person,
                                        fallbackIconColor:
                                            BleyaTheme.mutedForeground,
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: BleyaTheme.success,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: BleyaTheme.glassSurface,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (isCurrentUser) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: BleyaTheme.primary
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'YOU',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: BleyaTheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (member.username.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            member.phoneNumber,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: BleyaTheme.mutedForeground,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 20,
                                    color: BleyaTheme.mutedForeground,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: ErrorState(
                      title: 'Error loading members',
                      description: error.toString(),
                      onRetry: () {
                        ref.invalidate(roomMembersProvider(widget.roomId));
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
