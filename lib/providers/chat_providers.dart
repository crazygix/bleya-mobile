import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import '../services/socket_service.dart';
import '../domain/entities/room.dart';
import '../domain/entities/message.dart';
import '../domain/entities/room_member.dart';
import '../data/dtos/message_dto.dart';
import '../data/dtos/room_dto.dart';
import 'use_case_providers.dart';

export '../domain/entities/room.dart';
export '../domain/entities/message.dart';
export '../domain/entities/room_member.dart';

/// Tracks which room (if any) is currently open in the chat UI.
final currentOpenRoomIdProvider = StateProvider<String?>((ref) => null);

/// Tracks which thread (if any) is currently open in the chat UI.
final currentOpenThreadIdProvider = StateProvider<String?>((ref) => null);

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

// Provider to fetch available rooms
final availableRoomsProvider = FutureProvider<List<Room>>((ref) async {
  try {
    final useCase = ref.read(getAvailableRoomsUseCaseProvider);
    return await useCase();
  } catch (e, stack) {
    if (kDebugMode) {
      print('Error in availableRoomsProvider: $e');
      print('Stack: $stack');
    }
    rethrow;
  }
});

// Provider to fetch joined rooms from backend (single source of truth)
final AutoDisposeFutureProvider<List<Room>> joinedRoomsFutureProvider =
    FutureProvider.autoDispose<List<Room>>((ref) async {
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
      // Ensure socket is connected so per-user dashboard events can be received.
      await socketService.ensureConnectedForUserChannel();

      // Listen for lightweight room summary updates pushed via socket.
      // Registering before REST fetch avoids dropping updates during initial load.
      _roomSummaryHandler = socketService.addListener(
          'room_summary_updated', _onRoomSummaryUpdated);

      // Initial load from REST API (same data as joinedRoomsFutureProvider).
      final getJoinedRoomsUseCase = ref.read(getJoinedRoomsUseCaseProvider);
      final rooms = await getJoinedRoomsUseCase();

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
      _refreshRoomsFromBackend();
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

  Future<void> _refreshRoomsFromBackend() async {
    if (_isRefreshingRooms) return;
    _isRefreshingRooms = true;

    try {
      final getJoinedRoomsUseCase = ref.read(getJoinedRoomsUseCaseProvider);
      final rooms = await getJoinedRoomsUseCase();
      if (rooms.isEmpty && state.value == null) {
        return;
      }

      final existingItems = state.value ?? const <RoomListItem>[];
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
    final socketService = ref.read(socketServiceProvider);
    return RoomsListController(ref, socketService);
  },
);

// Provider for current room messages
final roomMessagesProvider =
    StateProvider.family<List<Message>, String>((ref, roomId) => []);

/// UI state for a chat room, excluding the actual message list which is kept
/// in [roomMessagesProvider] as a single source of truth for messages.
class ChatRoomState {
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final DateTime? lastReadAt;

  // Sentinel used in copyWith so we can distinguish
  // "parameter not provided" from "explicitly set to null".
  static const Object _noLastReadAtProvided = Object();

  const ChatRoomState({
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.nextCursor,
    required this.lastReadAt,
  });

  const ChatRoomState.initial()
      : isInitialLoading = true,
        isLoadingMore = false,
        hasMore = false,
        nextCursor = null,
        lastReadAt = null;

  ChatRoomState copyWith({
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    Object? lastReadAt = _noLastReadAtProvided,
  }) {
    return ChatRoomState(
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      lastReadAt: identical(lastReadAt, _noLastReadAtProvided)
          ? this.lastReadAt
          : lastReadAt as DateTime?,
    );
  }
}

// ThreadController manages thread state and real-time updates
class ThreadController extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final Ref ref;
  final String messageId;
  final SocketService socketService;
  bool _isInitialized = false;
  dynamic _socketHandler;

  ThreadController(this.ref, this.messageId, this.socketService)
      : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final getThreadUseCase = ref.read(getThreadUseCaseProvider);
      final threadData = await getThreadUseCase(messageId);

      state = AsyncValue.data({
        'parentMessage': threadData.parentMessage,
        'replies': threadData.replies,
      });

      // Listen to socket events for new replies
      _socketHandler = socketService.addListener('new_message', (data) {
        final message = MessageDto.fromJson(data);
        // If this is a reply to our thread's parent message
        if (message.parentMessageId == messageId) {
          final currentState = state.value;
          if (currentState != null) {
            final currentReplies = currentState['replies'] as List<Message>;
            // Check if reply already exists (avoid duplicates)
            if (!currentReplies.any((m) => m.id == message.id)) {
              state = AsyncValue.data({
                'parentMessage': currentState['parentMessage'],
                'replies': [...currentReplies, message],
              });
            }
          }
        }
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  @override
  void dispose() {
    if (_socketHandler != null) {
      socketService.removeListener('new_message', _socketHandler);
    }
    super.dispose();
  }
}

// Provider for thread messages with real-time updates
final threadMessagesProvider = StateNotifierProvider.autoDispose
    .family<ThreadController, AsyncValue<Map<String, dynamic>>, String>(
  (ref, messageId) {
    final socketService = ref.read(socketServiceProvider);
    return ThreadController(ref, messageId, socketService);
  },
);

// ChatRoomController manages socket listeners, pagination, and room operations
class ChatRoomController extends StateNotifier<ChatRoomState> {
  final Ref ref;
  final Room room;
  final SocketService socketService;
  bool _isInitialized = false;
  bool _disposed = false;

  // Store handler references returned from socketService so we can remove only our specific listeners
  dynamic _roomJoinedHandler;
  dynamic _newMessageHandler;
  dynamic _errorHandler;

  ChatRoomController(this.ref, this.room, this.socketService)
      : super(const ChatRoomState.initial()) {
    _initialize();
  }

  String get roomId => room.id;

  void _initialize() {
    if (_isInitialized) {
      // If already initialized, check if we need to rejoin the room
      // This handles the case where we navigate back to a room we were previously in
      _joinRoom();
      return;
    }
    _isInitialized = true;

    _setupSocketListeners();
    _joinRoom();
  }

  void _setupSocketListeners() {
    // Register room_joined listener and store handler reference
    _roomJoinedHandler = socketService.addListener('room_joined', (data) {
      // Ignore events if this controller has been disposed
      if (_disposed) return;

      // Only process if this is for our room
      final roomData = data['room'] as Map<String, dynamic>?;
      final joinedRoomId = roomData?['id'] as String?;
      if (joinedRoomId == roomId) {
        // Confirm room join in socket service
        final joinedRoom = RoomDto.fromJson(roomData!);
        socketService.onRoomJoinedConfirmed(joinedRoom);
        final messages = (data['messages'] as List)
            .map((m) => MessageDto.fromJson(m))
            .toList();
        ref.read(roomMessagesProvider(roomId).notifier).state = messages;

        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
        final hasMore = pagination['hasMore'] as bool? ?? false;
        final nextCursor = pagination['nextCursor'] as String?;
        final lastReadAtMs = data['lastReadAt'] as int?;
        final lastReadAt = lastReadAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastReadAtMs)
            : null;

        state = state.copyWith(
          isInitialLoading: false,
          hasMore: hasMore,
          nextCursor: nextCursor,
          lastReadAt: lastReadAt,
        );
      }
    });

    // Register new_message listener and store handler reference
    _newMessageHandler = socketService.addListener('new_message', (data) {
      // Ignore events if this controller has been disposed
      if (_disposed) return;

      final message = MessageDto.fromJson(data);
      // Only process if it's for this room
      if (message.roomId == roomId) {
        final currentMessages = ref.read(roomMessagesProvider(roomId));

        // If this is a thread reply, update the parent message's replyCount
        if (message.parentMessageId != null) {
          final updatedMessages = currentMessages.map((msg) {
            if (msg.id == message.parentMessageId) {
              // Return updated message with incremented replyCount
              return Message(
                id: msg.id,
                roomId: msg.roomId,
                userId: msg.userId,
                username: msg.username,
                text: msg.text,
                createdAt: msg.createdAt,
                parentMessageId: msg.parentMessageId,
                replyCount: msg.replyCount + 1,
              );
            }
            return msg;
          }).toList();

          ref.read(roomMessagesProvider(roomId).notifier).state =
              updatedMessages;
        } else {
          // Regular top-level message - add it to the list
          ref.read(roomMessagesProvider(roomId).notifier).state = [
            ...currentMessages,
            message,
          ];
        }
      }
    });

    // Register error listener and store handler reference
    _errorHandler = socketService.addListener('error', (data) {
      // Ignore events if this controller has been disposed
      if (_disposed) return;

      final rawError = data['error'];
      final errorMap =
          rawError is Map ? Map<String, dynamic>.from(rawError) : null;
      final errorCode = errorMap?['code']?.toString();
      final errorMsg = errorMap?['message']?.toString() ??
          data['message']?.toString() ??
          'An error occurred';
      if (kDebugMode) {
        print(
            'Socket error${errorCode != null ? ' [$errorCode]' : ''}: $errorMsg');
      }

      // If "Not in a room" error, try to rejoin
      if (errorMsg.contains('Not in a room')) {
        if (kDebugMode) {
          print('Attempting to rejoin room...');
        }
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_disposed) _joinRoom();
        });
      }
    });
  }

  void _joinRoom() {
    // SocketService already tracks the latest token via socketServiceProvider.
    // Joining should always use that latest token.
    socketService.joinRoom(room);
  }

  void sendMessage(String text, {String? parentMessageId}) {
    if (text.trim().isEmpty) return;

    final socket = socketService.socket;
    if (socket == null || !socket.connected) {
      if (kDebugMode) {
        print('Not connected. Cannot send message.');
      }
      return;
    }

    socketService.sendMessage(text, parentMessageId: parentMessageId);
  }

  /// Ensure we're in the room - call this when the page becomes visible again
  void ensureInRoom() {
    _joinRoom();
  }

  /// Load older top-level messages using REST pagination and prepend them.
  Future<void> loadOlderMessages({int? limit}) async {
    if (state.isLoadingMore || !state.hasMore) {
      return;
    }

    final currentCursor = state.nextCursor;
    if (currentCursor == null) {
      // No cursor available, nothing to load.
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final useCase = ref.read(getRoomMessagesPageUseCaseProvider);
      final page = await useCase(
        roomId,
        before: currentCursor,
        limit: limit,
      );

      if (_disposed) {
        return;
      }

      if (page.messages.isEmpty) {
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
        return;
      }

      final currentMessages = ref.read(roomMessagesProvider(roomId));
      // Prepend older messages, avoiding duplicates by id just in case.
      final existingIds = currentMessages.map((m) => m.id).toSet();
      final newMessages =
          page.messages.where((m) => !existingIds.contains(m.id)).toList();

      ref.read(roomMessagesProvider(roomId).notifier).state = [
        ...newMessages,
        ...currentMessages,
      ];

      state = state.copyWith(
        isLoadingMore: false,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        print('Error loading older messages for room $roomId: $e');
        print(stack);
      }
      state = state.copyWith(isLoadingMore: false);
    }
  }

  @override
  void dispose() {
    _disposed = true;

    // Clear messages for this room when leaving
    ref.read(roomMessagesProvider(roomId).notifier).state = [];

    // Remove only our specific socket listeners by passing the handler references
    if (_roomJoinedHandler != null) {
      socketService.removeListener('room_joined', _roomJoinedHandler);
    }
    if (_newMessageHandler != null) {
      socketService.removeListener('new_message', _newMessageHandler);
    }
    if (_errorHandler != null) {
      socketService.removeListener('error', _errorHandler);
    }

    // Note: leaveRoom is called by ChatRoomPage.dispose() to avoid double-leaving
    super.dispose();
  }
}

// Provider for ChatRoomController (family provider for each room)
// Using autoDispose so the controller is disposed when no longer watched
final chatRoomControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatRoomController, ChatRoomState, Room>(
  (ref, room) {
    final socketService = ref.read(socketServiceProvider);
    return ChatRoomController(ref, room, socketService);
    // Note: StateNotifierProvider automatically calls dispose() on the notifier
  },
);

// Provider to fetch room members
final roomMembersProvider =
    FutureProvider.family<List<RoomMember>, String>((ref, roomId) async {
  try {
    final roomRepository = ref.read(roomRepositoryProvider);
    return await roomRepository.getRoomMembers(roomId);
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching room members: $e');
    }
    rethrow;
  }
});

// Function to leave a room
Future<void> leaveRoom(WidgetRef ref, String roomId) async {
  try {
    final useCase = ref.read(leaveRoomUseCaseProvider);
    await useCase(roomId);

    // Refresh joined rooms from backend
    ref.invalidate(joinedRoomsFutureProvider);
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

    return room;
  } catch (e) {
    if (kDebugMode) {
      print('Error creating direct message: $e');
    }
    rethrow;
  }
}
