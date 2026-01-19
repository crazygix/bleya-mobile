import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../utils/app_errors.dart';
import '../constants/theme.dart';
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
      appBar: AppBar(
        title: Text(widget.roomName),
      ),
      body: Column(
        children: [
          // Leave Room Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Leave Room'),
                    content:
                        const Text('Are you sure you want to leave this room?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Leave',
                            style: TextStyle(color: BleyaTheme.error)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  try {
                    await leaveRoom(ref, widget.roomId);
                    if (context.mounted) {
                      // Navigate to home and remove all routes except the initial route
                      // This is more reliable than popUntil which may not find the route by name
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
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Leave Room'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BleyaTheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const Divider(),
          // Members List
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Members',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                membersAsync.when(
                  data: (members) => Text(
                    '(${members.length})',
                    style: TextStyle(
                      fontSize: 18,
                      color: BleyaTheme.greyText,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: membersAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return const Center(
                    child: Text('No members in this room'),
                  );
                }
                return ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final displayName = member.username.isNotEmpty
                        ? member.username
                        : member.phoneNumber;
                    final isCurrentUser =
                        currentUserId != null && member.id == currentUserId;

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: BleyaTheme.greyBorder,
                        backgroundImage: member.profileImageUrl.isNotEmpty &&
                                member.profileImageUrl.startsWith('https://')
                            ? NetworkImage(member.profileImageUrl)
                            : null,
                        onBackgroundImageError: member
                                    .profileImageUrl.isNotEmpty &&
                                member.profileImageUrl.startsWith('https://')
                            ? (exception, stackTrace) {
                                if (kDebugMode) {
                                  print(
                                      'Error loading profile image: $exception');
                                }
                              }
                            : null,
                        child: member.profileImageUrl.isEmpty ||
                                !member.profileImageUrl.startsWith('https://')
                            ? Icon(Icons.person, color: BleyaTheme.greyText)
                            : null,
                      ),
                      title: Row(
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: BleyaTheme.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: BleyaTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: member.username.isNotEmpty
                          ? Text(member.phoneNumber)
                          : null,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => UserDetailsPage(
                              userId: member.id,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: BleyaTheme.error),
                    const SizedBox(height: 16),
                    Text('Error loading members: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(roomMembersProvider(widget.roomId));
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
