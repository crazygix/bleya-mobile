import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../utils/app_errors.dart';
import 'user_details_page.dart';

class RoomDetailsPage extends ConsumerWidget {
  final String roomId;
  final String roomName;

  const RoomDetailsPage({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(roomMembersProvider(roomId));
    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUserId = currentUserAsync.value?['id'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(roomName),
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
                    content: const Text('Are you sure you want to leave this room?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Leave', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  try {
                    await leaveRoom(ref, roomId);
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      String errorMessage;
                      if (e is AppError) {
                        errorMessage = e.getUserMessage();
                      } else {
                        errorMessage = 'Failed to leave room. Please try again.';
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
                backgroundColor: Colors.red,
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
                      color: Colors.grey[600],
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
                    final isCurrentUser = currentUserId != null && member.id == currentUserId;

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: member.profileImageUrl.isNotEmpty &&
                                member.profileImageUrl.startsWith('https://')
                            ? NetworkImage(member.profileImageUrl)
                            : null,
                        onBackgroundImageError: member.profileImageUrl.isNotEmpty &&
                                member.profileImageUrl.startsWith('https://')
                            ? (exception, stackTrace) {
                                print('Error loading profile image: $exception');
                              }
                            : null,
                        child: member.profileImageUrl.isEmpty ||
                                !member.profileImageUrl.startsWith('https://')
                            ? const Icon(Icons.person, color: Colors.grey)
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
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading members: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(roomMembersProvider(roomId));
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

