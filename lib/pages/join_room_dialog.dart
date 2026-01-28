import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../utils/app_errors.dart';
import '../constants/theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';

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
          errorMessage = "Couldn't join that room. Try again?";
        } else {
          errorMessage = "Something unexpected happened. Try again?";
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
                      return EmptyState(
                        icon: CupertinoIcons.chat_bubble,
                        title: 'No rooms available',
                        description: 'Check back later for new rooms',
                      );
                    }

                    // Filter out already joined rooms
                    final availableRooms = rooms
                        .where((room) =>
                            !joinedRooms.any((jr) => jr.id == room.id))
                        .toList();

                    if (availableRooms.isEmpty) {
                      final publicRoomCount =
                          joinedRooms.where((r) => r.type == 'public').length;
                      return EmptyState(
                        icon: CupertinoIcons.checkmark_circle,
                        title: 'You have joined all available rooms',
                        description: publicRoomCount >= 5
                            ? 'You have reached the limit of 5 group chats'
                            : 'Check back later for new rooms',
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableRooms.length,
                      itemBuilder: (context, index) {
                        final room = availableRooms[index];
                        final isJoiningThis = _isJoining;
                        return ListTile(
                          leading: ProfileAvatar(
                            imageUrl: null,
                            size: 40,
                            backgroundColor: BleyaTheme.primaryLight,
                            fallbackIcon: CupertinoIcons.person_2_fill,
                            fallbackIconColor: BleyaTheme.primaryDark,
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
                      child: ErrorState(
                        title: 'Error loading rooms',
                        description: error.toString(),
                        onRetry: () {
                          ref.invalidate(availableRoomsProvider);
                        },
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
