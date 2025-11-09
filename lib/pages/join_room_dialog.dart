import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';

class JoinRoomDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends ConsumerState<JoinRoomDialog> {
  @override
  void initState() {
    super.initState();
    // Refresh rooms when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(availableRoomsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(availableRoomsProvider);
    final joinedRooms = ref.watch(joinedRoomsProvider);

    return Dialog(
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Join a Room',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: roomsAsync.when(
                data: (rooms) {
                  if (rooms.isEmpty) {
                    return const Center(child: Text('No rooms available'));
                  }

                  // Filter out already joined rooms
                  final availableRooms = rooms
                      .where(
                          (room) => !joinedRooms.any((jr) => jr.id == room.id))
                      .toList();

                  if (availableRooms.isEmpty) {
                    return const Center(
                      child: Text('You have joined all available rooms'),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableRooms.length,
                    itemBuilder: (context, index) {
                      final room = availableRooms[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(room.name[0].toUpperCase()),
                        ),
                        title: Text(room.name),
                        onTap: () {
                          // Add room to joined rooms
                          ref.read(joinedRoomsProvider.notifier).state = [
                            ...joinedRooms,
                            room,
                          ];
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) {
                  print('Error fetching rooms: $error');
                  print('Stack: $stack');
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading rooms',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(availableRoomsProvider);
                          },
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
