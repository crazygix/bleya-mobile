import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';
import '../services/socket_service.dart';
import '../domain/entities/room.dart';
import '../domain/entities/room_member.dart';
import '../domain/entities/direct_chat_status.dart';
import 'use_case_providers.dart';

export '../domain/entities/room.dart';
export '../domain/entities/message.dart';
export '../domain/entities/room_member.dart';
export '../domain/entities/direct_chat_status.dart';
export 'chat_room_providers.dart';

/// Tracks which room (if any) is currently open in the chat UI.
final currentOpenRoomIdProvider = StateProvider<String?>((ref) {
  ref.watch(sessionVersionProvider);
  return null;
});

/// Tracks which thread (if any) is currently open in the chat UI.
final currentOpenThreadIdProvider = StateProvider<String?>((ref) {
  ref.watch(sessionVersionProvider);
  return null;
});

/// Wrapper model for a room along with its local unread count.
class RoomListItem {
  final Room room;
  final int unreadCount;

  const RoomListItem({
    required this.room,
    required this.unreadCount,
  });

  RoomListItem copyWith({
    Room? room,
    int? unreadCount,
  }) {
    return RoomListItem(
      room: room ?? this.room,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// Provider to fetch joined rooms from backend (single source of truth)
final AutoDisposeFutureProvider<List<Room>> joinedRoomsFutureProvider =
    FutureProvider.autoDispose<List<Room>>((ref) async {
  ref.watch(sessionVersionProvider);
  try {
    final token = ref.read(tokenProvider);
    if (token == null || token.isEmpty) {
      return [];
    }

    final useCase = ref.read(getJoinedRoomsUseCaseProvider);
    return await useCase();
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching joined rooms: $e');
    }
    return [];
  }
});

final directChatStatusProvider =
    FutureProvider.autoDispose.family<DirectChatStatus, String>(
  (ref, otherUserId) async {
    ref.watch(sessionVersionProvider);
    final useCase = ref.read(getDirectChatStatusUseCaseProvider);
    return await useCase(otherUserId);
  },
);

/// Controller for the rooms list on the dashboard, including realtime updates
/// from the socket and per-session unread counts.
class RoomsListController
    extends StateNotifier<AsyncValue<List<RoomListItem>>> {
  final Ref ref;
  final SocketService socketService;

  bool _isInitialized = false;
  bool _isRefreshingRooms = false;
  bool _hasLoggedUnreadFallback = false;
  dynamic _roomSummaryHandler;
  final Map<String, Map<String, dynamic>> _pendingRoomSummaries = {};
  final Map<String, int> _pendingUnreadIncrements = {};

  RoomsListController(this.ref, this.socketService)
      : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final token = ref.read(tokenProvider);
      if (token == null || token.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      // Ensure socket is connected so per-user dashboard events can be received.
      await socketService.ensureConnectedForUserChannel();
      // Disposed meanwhile (the session changed): register nothing.
      if (!mounted) return;

      // Listen for lightweight room summary updates pushed via socket.
      // Registering before REST fetch avoids dropping updates during initial load.
      _roomSummaryHandler = socketService.addListener(
          'room_summary_updated', _onRoomSummaryUpdated);

      // Initial load from REST API (same data as joinedRoomsFutureProvider).
      final getJoinedRoomsUseCase = ref.read(getJoinedRoomsUseCaseProvider);
      final rooms = await getJoinedRoomsUseCase();
      if (!mounted) return;

      var items = rooms
          .map(
            (room) => RoomListItem(
              room: room,
              unreadCount: _initialUnreadForRoom(room),
            ),
          )
          .toList();

      if (_pendingRoomSummaries.isNotEmpty) {
        for (final entry in _pendingRoomSummaries.entries) {
          final roomId = entry.key;
          final unreadIncrement = _pendingUnreadIncrements[roomId] ?? 0;
          items = _applySummaryUpdate(
            items,
            roomId: roomId,
            payload: entry.value,
            unreadIncrement: unreadIncrement,
          );
        }
        _pendingRoomSummaries.clear();
        _pendingUnreadIncrements.clear();
      }

      _sortByLastMessageTime(items);
      state = AsyncValue.data(items);
    } catch (e, stack) {
      if (!mounted) return;
      state = AsyncValue.error(e, stack);
    }
  }

  void _onRoomSummaryUpdated(Map<String, dynamic> data) {
    final roomId = data['roomId'] as String?;
    if (roomId == null || roomId.isEmpty) return;

    final openRoomId = ref.read(currentOpenRoomIdProvider);
    final currentUser = ref.read(currentUserProvider);
    final currentUserId = currentUser?['id']?.toString();
    final messageUserId = data['lastMessageUserId']?.toString();
    final isOwnMessage =
        currentUserId != null && messageUserId == currentUserId;
    final unreadIncrement = (openRoomId == roomId || isOwnMessage) ? 0 : 1;

    final current = state.value;
    if (current == null) {
      _pendingRoomSummaries[roomId] = data;
      _pendingUnreadIncrements[roomId] =
          (_pendingUnreadIncrements[roomId] ?? 0) + unreadIncrement;
      return;
    }

    final roomExists = current.any((item) => item.room.id == roomId);
    if (!roomExists) {
      _pendingRoomSummaries[roomId] = data;
      _pendingUnreadIncrements[roomId] =
          (_pendingUnreadIncrements[roomId] ?? 0) + unreadIncrement;
      refresh();
      return;
    }

    final updated = _applySummaryUpdate(
      current,
      roomId: roomId,
      payload: data,
      unreadIncrement: unreadIncrement,
    );

    if (!identical(updated, current)) {
      state = AsyncValue.data(updated);
    }
  }

  Future<void> refresh() async {
    if (_isRefreshingRooms) return;
    _isRefreshingRooms = true;

    try {
      if (_roomSummaryHandler == null) {
        await socketService.ensureConnectedForUserChannel();
        if (!mounted) return;
        _roomSummaryHandler = socketService.addListener(
          'room_summary_updated',
          _onRoomSummaryUpdated,
        );
      }

      final getJoinedRoomsUseCase = ref.read(getJoinedRoomsUseCaseProvider);
      final rooms = await getJoinedRoomsUseCase();
      if (!mounted) return;

      final existingItems = state.valueOrNull ?? const <RoomListItem>[];
      final existingUnreadByRoomId = <String, int>{
        for (final item in existingItems) item.room.id: item.unreadCount,
      };

      var refreshedItems = rooms
          .map(
            (room) => RoomListItem(
              room: room,
              unreadCount: existingUnreadByRoomId[room.id] ??
                  _initialUnreadForRoom(room),
            ),
          )
          .toList();

      if (_pendingRoomSummaries.isNotEmpty) {
        final unresolvedSummaries = <String, Map<String, dynamic>>{};
        final unresolvedUnreadIncrements = <String, int>{};

        for (final entry in _pendingRoomSummaries.entries) {
          final roomId = entry.key;
          final unreadIncrement = _pendingUnreadIncrements[roomId] ?? 0;
          final roomExists =
              refreshedItems.any((item) => item.room.id == roomId);

          if (!roomExists) {
            unresolvedSummaries[roomId] = entry.value;
            unresolvedUnreadIncrements[roomId] = unreadIncrement;
            continue;
          }

          refreshedItems = _applySummaryUpdate(
            refreshedItems,
            roomId: roomId,
            payload: entry.value,
            unreadIncrement: unreadIncrement,
          );
        }

        _pendingRoomSummaries
          ..clear()
          ..addAll(unresolvedSummaries);
        _pendingUnreadIncrements
          ..clear()
          ..addAll(unresolvedUnreadIncrements);
      }

      _sortByLastMessageTime(refreshedItems);
      state = AsyncValue.data(refreshedItems);
    } catch (e, stack) {
      if (kDebugMode) {
        print('Error refreshing joined rooms for realtime updates: $e');
        print(stack);
      }
    } finally {
      _isRefreshingRooms = false;
    }
  }

  int _initialUnreadForRoom(Room room) {
    if (room.hasUnreadCount) {
      return room.unreadCount;
    }

    if (!_hasLoggedUnreadFallback && kDebugMode) {
      _hasLoggedUnreadFallback = true;
      print('rooms/joined missing unreadCount; using last-message fallback');
    }

    final currentUser = ref.read(currentUserProvider);
    final currentUserId = currentUser?['id']?.toString();
    final lastMessageUserId = room.lastMessageUserId;
    final hasLastMessage = room.lastMessageText != null;

    if (!hasLastMessage || lastMessageUserId == null) {
      return 0;
    }

    return lastMessageUserId == currentUserId ? 0 : 1;
  }

  List<RoomListItem> _applySummaryUpdate(
    List<RoomListItem> source, {
    required String roomId,
    required Map<String, dynamic> payload,
    required int unreadIncrement,
  }) {
    final index = source.indexWhere((item) => item.room.id == roomId);
    if (index == -1) return source;

    final existingItem = source[index];
    final existingRoom = existingItem.room;

    final updatedRoom = Room(
      id: existingRoom.id,
      name: existingRoom.name,
      type: existingRoom.type,
      participants: existingRoom.participants,
      otherUserId: existingRoom.otherUserId,
      lastMessageText: payload['lastMessageText']?.toString() ??
          existingRoom.lastMessageText,
      lastMessageTime: _parseTimestamp(payload['lastMessageTime']) ??
          existingRoom.lastMessageTime,
      lastMessageUserId: payload['lastMessageUserId']?.toString() ??
          existingRoom.lastMessageUserId,
      lastMessageUsername: payload['lastMessageUsername']?.toString() ??
          existingRoom.lastMessageUsername,
      imageUrl: payload['imageUrl']?.toString() ?? existingRoom.imageUrl,
      cityKey: existingRoom.cityKey,
      location: existingRoom.location,
      distanceKm: existingRoom.distanceKm,
      isJoined: existingRoom.isJoined,
    );

    final openRoomId = ref.read(currentOpenRoomIdProvider);
    final isRoomOpen = openRoomId == roomId;
    final updatedUnread =
        isRoomOpen ? 0 : existingItem.unreadCount + unreadIncrement;

    final updatedList = [...source];
    updatedList[index] = existingItem.copyWith(
      room: updatedRoom,
      unreadCount: updatedUnread,
    );

    _sortByLastMessageTime(updatedList);
    return updatedList;
  }

  DateTime? _parseTimestamp(dynamic rawValue) {
    if (rawValue is int) {
      return DateTime.fromMillisecondsSinceEpoch(rawValue);
    }
    if (rawValue is double) {
      return DateTime.fromMillisecondsSinceEpoch(rawValue.round());
    }
    if (rawValue is String) {
      final parsed = int.tryParse(rawValue);
      if (parsed != null) {
        return DateTime.fromMillisecondsSinceEpoch(parsed);
      }
    }
    return null;
  }

  void _sortByLastMessageTime(List<RoomListItem> items) {
    items.sort((a, b) {
      final aTime =
          a.room.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.room.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  }

  /// Mark a room as read locally (resets unread counter).
  void markRoomAsRead(String roomId) {
    final current = state.value;
    if (current == null) return;

    final updated = current
        .map(
          (item) =>
              item.room.id == roomId ? item.copyWith(unreadCount: 0) : item,
        )
        .toList();

    state = AsyncValue.data(updated);

    // Best-effort: inform backend that this room has been read so that
    // join_room can return an accurate lastReadAt cursor next time.
    // This is fire-and-forget; errors are logged in debug but do not
    // affect UI state.
    Future(() async {
      try {
        final markReadUseCase = ref.read(markRoomAsReadUseCaseProvider);
        await markReadUseCase(roomId);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to mark room $roomId as read on backend: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    if (_roomSummaryHandler != null) {
      socketService.removeListener(
        'room_summary_updated',
        _roomSummaryHandler,
      );
    }
    super.dispose();
  }
}

/// Provider exposing the realtime rooms list with unread counts.
final roomsListProvider =
    StateNotifierProvider<RoomsListController, AsyncValue<List<RoomListItem>>>(
  (ref) {
    ref.watch(sessionVersionProvider);
    final socketService = ref.read(socketServiceProvider);
    return RoomsListController(ref, socketService);
  },
);

/// Room members loaded so far, one page at a time.
class RoomMembersState {
  final List<RoomMember> members;

  /// Whether the server may have more members than [members]; the list is
  /// only complete once a page comes back short.
  final bool hasMore;
  final bool isLoadingMore;

  const RoomMembersState({
    required this.members,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  RoomMembersState copyWith({bool? isLoadingMore}) {
    return RoomMembersState(
      members: members,
      hasMore: hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Pages through `GET /rooms/:id/members`, which returns a bare array sorted
/// by username.
class RoomMembersController
    extends StateNotifier<AsyncValue<RoomMembersState>> {
  static const pageSize = 100;

  final Ref ref;
  final String roomId;

  RoomMembersController(this.ref, this.roomId)
      : super(const AsyncValue.loading()) {
    _loadFirstPage();
  }

  Future<List<RoomMember>> _fetchPage(int offset) {
    return ref.read(getRoomMembersUseCaseProvider)(
      roomId,
      limit: pageSize,
      offset: offset,
    );
  }

  Future<void> _loadFirstPage() async {
    final token = ref.read(tokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data(
        RoomMembersState(members: [], hasMore: false),
      );
      return;
    }

    try {
      final page = await _fetchPage(0);
      if (!mounted) return;
      state = AsyncValue.data(
        RoomMembersState(members: page, hasMore: page.length == pageSize),
      );
    } catch (e, stack) {
      if (kDebugMode) {
        print('Error fetching room members: $e');
      }
      if (!mounted) return;
      state = AsyncValue.error(e, stack);
    }
  }

  /// Loads the next page, if there is one and none is loading.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final page = await _fetchPage(current.members.length);
      if (!mounted) return;
      // Members can join or leave between pages; don't list anyone twice.
      final seenIds = current.members.map((member) => member.id).toSet();
      state = AsyncValue.data(
        RoomMembersState(
          members: [
            ...current.members,
            ...page.where((member) => seenIds.add(member.id)),
          ],
          hasMore: page.length == pageSize,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching more room members: $e');
      }
      if (!mounted) return;
      // Keep what's loaded; scrolling again retries.
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

// Provider to fetch room members
final roomMembersProvider = StateNotifierProvider.autoDispose
    .family<RoomMembersController, AsyncValue<RoomMembersState>, String>(
  (ref, roomId) {
    ref.watch(sessionVersionProvider);
    return RoomMembersController(ref, roomId);
  },
);

// Function to leave a room
Future<void> leaveRoom(WidgetRef ref, String roomId) async {
  try {
    final useCase = ref.read(leaveRoomUseCaseProvider);
    await useCase(roomId);

    // Refresh joined rooms from backend
    ref.invalidate(joinedRoomsFutureProvider);
    ref.invalidate(roomsListProvider);
  } catch (e) {
    if (kDebugMode) {
      print('Error leaving room: $e');
    }
    rethrow;
  }
}

// Function to create or get direct message room with a user
Future<Room> createDirectMessage(WidgetRef ref, String otherUserId) async {
  try {
    final useCase = ref.read(createDirectMessageUseCaseProvider);
    final room = await useCase(otherUserId);

    // Refresh joined rooms from backend
    ref.invalidate(joinedRoomsFutureProvider);
    ref.invalidate(roomsListProvider);
    ref.invalidate(directChatStatusProvider(otherUserId));

    return room;
  } catch (e) {
    if (kDebugMode) {
      print('Error creating direct message: $e');
    }
    rethrow;
  }
}

Future<DirectChatActionResult> deleteDirectChat(
  WidgetRef ref,
  String otherUserId,
) async {
  try {
    final useCase = ref.read(deleteDirectChatUseCaseProvider);
    final result = await useCase(otherUserId);

    ref.invalidate(joinedRoomsFutureProvider);
    ref.invalidate(roomsListProvider);
    ref.invalidate(directChatStatusProvider(otherUserId));

    return result;
  } catch (e) {
    if (kDebugMode) {
      print('Error deleting direct chat: $e');
    }
    rethrow;
  }
}

Future<DirectChatActionResult> blockDirectChat(
  WidgetRef ref,
  String otherUserId,
) async {
  try {
    final useCase = ref.read(blockDirectChatUseCaseProvider);
    final result = await useCase(otherUserId);

    ref.invalidate(joinedRoomsFutureProvider);
    ref.invalidate(roomsListProvider);
    ref.invalidate(directChatStatusProvider(otherUserId));

    return result;
  } catch (e) {
    if (kDebugMode) {
      print('Error blocking direct chat: $e');
    }
    rethrow;
  }
}

Future<DirectChatActionResult> unblockDirectChat(
  WidgetRef ref,
  String otherUserId,
) async {
  try {
    final useCase = ref.read(unblockDirectChatUseCaseProvider);
    final result = await useCase(otherUserId);

    ref.invalidate(joinedRoomsFutureProvider);
    ref.invalidate(roomsListProvider);
    ref.invalidate(directChatStatusProvider(otherUserId));

    return result;
  } catch (e) {
    if (kDebugMode) {
      print('Error unblocking direct chat: $e');
    }
    rethrow;
  }
}
