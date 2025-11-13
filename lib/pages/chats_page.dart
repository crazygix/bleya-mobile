import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import 'chat_room_page.dart';

class ChatsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize joined rooms from backend on first load
    ref.watch(joinedRoomsFutureProvider);
    final joinedRooms = ref.watch(joinedRoomsProvider);

    if (joinedRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No rooms joined yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to join a room',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: joinedRooms.length,
      itemBuilder: (context, index) {
        final room = joinedRooms[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(room.name[0].toUpperCase()),
          ),
          title: Text(room.name),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatRoomPage(
                  roomId: room.id,
                  roomName: room.name,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
