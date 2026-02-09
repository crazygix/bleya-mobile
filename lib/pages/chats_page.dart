import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../constants/theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/profile_avatar.dart';
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
                  isPrivate ? 'Direct message' : 'Group chat',
                  style: TextStyle(
                    fontSize: 12,
                    color: BleyaTheme.greyText,
                  ),
                ),
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
