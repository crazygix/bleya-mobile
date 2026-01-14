import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../utils/app_errors.dart';
import '../constants/theme.dart';

class JoinRoomDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends ConsumerState<JoinRoomDialog> {
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    // Refresh rooms when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(availableRoomsProvider);
    });
  }

  Future<void> _joinRoom(Room room) async {
    if (_isJoining) return;

    setState(() => _isJoining = true);

    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/rooms/${room.id}/join',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      // Refresh joined rooms from backend
      ref.invalidate(joinedRoomsFutureProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully joined ${room.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage;
        if (e is AppError) {
          errorMessage = e.getUserMessage();
        } else if (e is DioException) {
          // This shouldn't happen if services are using AppError, but handle it just in case
          errorMessage = 'Failed to join room. Please try again.';
        } else {
          errorMessage = 'An unexpected error occurred. Please try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: BleyaTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(availableRoomsProvider);
    final joinedRoomsAsync = ref.watch(joinedRoomsFutureProvider);

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
              child: joinedRoomsAsync.when(
                data: (joinedRooms) => roomsAsync.when(
                  data: (rooms) {
                    if (rooms.isEmpty) {
                      return const Center(child: Text('No rooms available'));
                    }

                    // Filter out already joined rooms
                    final availableRooms = rooms
                        .where((room) =>
                            !joinedRooms.any((jr) => jr.id == room.id))
                        .toList();

                    if (availableRooms.isEmpty) {
                      final publicRoomCount =
                          joinedRooms.where((r) => r.type == 'public').length;
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('You have joined all available rooms'),
                            if (publicRoomCount >= 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'You have reached the limit of 5 group chats',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: BleyaTheme.greyText,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableRooms.length,
                      itemBuilder: (context, index) {
                        final room = availableRooms[index];
                        final isJoiningThis = _isJoining;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(room.name[0].toUpperCase()),
                          ),
                          title: Text(room.name),
                          trailing: isJoiningThis
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : null,
                          onTap: isJoiningThis ? null : () => _joinRoom(room),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) {
                    if (kDebugMode) {
                      print('Error fetching rooms: $error');
                      print('Stack: $stack');
                    }
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              color: BleyaTheme.error, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading rooms',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.toString(),
                            style: TextStyle(
                                fontSize: 12, color: BleyaTheme.greyText),
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    const Center(child: Text('Error loading joined rooms')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
