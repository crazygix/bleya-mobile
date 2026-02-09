import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../constants/theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/profile_avatar.dart';
import '../utils/time_formatter.dart';
import 'chat_room_page.dart';

class ChatsPage extends ConsumerWidget {
  const ChatsPage({super.key});

  Future<void> _refreshRooms(WidgetRef ref) async {
    ref.invalidate(joinedRoomsFutureProvider);
    await ref.read(joinedRoomsFutureProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joinedRoomsAsync = ref.watch(joinedRoomsFutureProvider);
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;

    return joinedRoomsAsync.when(
      data: (joinedRooms) {
        if (joinedRooms.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _refreshRooms(ref),
            child: ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                EmptyState(
                  icon: CupertinoIcons.chat_bubble,
                  title: 'No rooms joined yet',
                  description: 'Tap the + button to join a room',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _refreshRooms(ref),
          child: ListView.builder(
            itemCount: joinedRooms.length,
            itemBuilder: (context, index) {
              final room = joinedRooms[index];
              final isPrivate = room.isPrivate;
              final hasLastMessage = room.lastMessageText != null;

              String subtitle;
              if (hasLastMessage) {
                String prefix = '';
                if (isPrivate && room.lastMessageUserId != null) {
                  final isCurrentUser = room.lastMessageUserId == currentUserId;
                  prefix = isCurrentUser ? 'You: ' : '${room.lastMessageUsername ?? 'Unknown'}: ';
                }
                subtitle = '$prefix${room.lastMessageText}';
              } else {
                subtitle = isPrivate ? 'Direct message' : 'Group chat';
              }

              return ListTile(
                leading: isPrivate
                    ? ProfileAvatar(
                        imageUrl: null,
                        size: 40,
                        backgroundColor: BleyaTheme.privateRoomLight,
                        fallbackIcon: CupertinoIcons.person,
                        fallbackIconColor: BleyaTheme.privateRoomDark,
                      )
                    : ProfileAvatar(
                        imageUrl: null,
                        size: 40,
                        backgroundColor: BleyaTheme.primaryLight,
                        fallbackIcon: CupertinoIcons.person_2,
                        fallbackIconColor: BleyaTheme.primaryDark,
                      ),
                title: Text(room.name),
                subtitle: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: BleyaTheme.greyText,
                  ),
                ),
                trailing: room.lastMessageTime != null
                    ? Text(
                        formatRelativeTime(room.lastMessageTime!),
                        style: TextStyle(
                          fontSize: 12,
                          color: BleyaTheme.greyText,
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatRoomPage(room: room),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => RefreshIndicator(
        onRefresh: () => _refreshRooms(ref),
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            ErrorState(
              title: 'Error loading rooms',
              description: 'Pull down to retry',
              onRetry: () => _refreshRooms(ref),
            ),
          ],
        ),
      ),
    );
  }
}
