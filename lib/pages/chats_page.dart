import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../constants/theme.dart';
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
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: BleyaTheme.greyText),
                      const SizedBox(height: 16),
                      Text(
                        'No rooms joined yet',
                        style: TextStyle(fontSize: 18, color: BleyaTheme.greyText),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to join a room',
                        style: TextStyle(fontSize: 14, color: BleyaTheme.greyText),
                      ),
                    ],
                  ),
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
                leading: CircleAvatar(
                  backgroundColor:
                      isPrivate ? BleyaTheme.privateRoomLight : BleyaTheme.primaryLight,
                  child: Icon(
                    isPrivate ? Icons.person : Icons.group,
                    color: isPrivate ? BleyaTheme.privateRoomDark : BleyaTheme.primaryDark,
                  ),
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
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: BleyaTheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading rooms',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to retry',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
