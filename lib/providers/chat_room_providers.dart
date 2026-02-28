import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/message.dart';
import '../domain/entities/room.dart';
import '../domain/repositories/message_repository.dart';
import '../services/socket_service.dart';
import 'auth_providers.dart';
import 'use_case_providers.dart';

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
class ThreadController extends StateNotifier<AsyncValue<ThreadData>> {
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
      state = AsyncValue.data(threadData);

      // Listen to socket events for new replies
      _socketHandler = socketService.addListener('new_message', (data) {
        final message = socketService.parseMessagePayload(data);
        if (message == null || message.parentMessageId != messageId) {
          return;
        }

        final currentState = state.value;
        if (currentState == null) return;

        // Check if reply already exists (avoid duplicates)
        final alreadyExists =
            currentState.replies.any((existing) => existing.id == message.id);
        if (alreadyExists) return;

        state = AsyncValue.data(
          ThreadData(
            parentMessage: currentState.parentMessage,
            replies: [...currentState.replies, message],
          ),
        );
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
    .family<ThreadController, AsyncValue<ThreadData>, String>(
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

      final joinedData = socketService.parseRoomJoinedPayload(data);
      if (joinedData == null || joinedData.room.id != roomId) {
        return;
      }

      // Confirm room join in socket service
      socketService.onRoomJoinedConfirmed(joinedData.room);
      ref.read(roomMessagesProvider(roomId).notifier).state = joinedData.messages;

      state = state.copyWith(
        isInitialLoading: false,
        hasMore: joinedData.hasMore,
        nextCursor: joinedData.nextCursor,
        lastReadAt: joinedData.lastReadAt,
      );
    });

    // Register new_message listener and store handler reference
    _newMessageHandler = socketService.addListener('new_message', (data) {
      // Ignore events if this controller has been disposed
      if (_disposed) return;

      final message = socketService.parseMessagePayload(data);
      if (message == null || message.roomId != roomId) {
        return;
      }

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

        ref.read(roomMessagesProvider(roomId).notifier).state = updatedMessages;
      } else {
        // Regular top-level message - add it to the list
        ref.read(roomMessagesProvider(roomId).notifier).state = [
          ...currentMessages,
          message,
        ];
      }
    });

    // Register error listener and store handler reference
    _errorHandler = socketService.addListener('error', (data) {
      // Ignore events if this controller has been disposed
      if (_disposed) return;

      final socketError = socketService.parseErrorPayload(data);
      if (kDebugMode) {
        print(
            'Socket error${socketError.code != null ? ' [${socketError.code}]' : ''}: ${socketError.message}');
      }

      // If "Not in a room" error, try to rejoin
      if (socketError.message.contains('Not in a room')) {
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
