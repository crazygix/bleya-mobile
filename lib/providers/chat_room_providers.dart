import 'dart:async';

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
    StateProvider.autoDispose.family<List<Message>, String>((ref, roomId) {
  ref.watch(sessionVersionProvider);
  return [];
});

/// Set when a moderator removes a thread's parent message; the open thread
/// page closes. Provider state (not a stream on the controller) so the page
/// still hears it after a retry recreates the controller.
final threadParentRemovedProvider =
    StateProvider.autoDispose.family<bool, String>((ref, messageId) => false);

/// Users blocked during this session. Their messages already on screen are
/// hidden straight away; the server stops sending new ones.
final sessionBlockedUserIdsProvider = StateProvider<Set<String>>((ref) {
  ref.watch(sessionVersionProvider);
  return const <String>{};
});

/// Records a block or unblock so open chats update without reloading.
void setUserBlockedInSession(WidgetRef ref, String userId, bool blocked) {
  final notifier = ref.read(sessionBlockedUserIdsProvider.notifier);
  final next = {...notifier.state};
  final changed = blocked ? next.add(userId) : next.remove(userId);
  if (changed) {
    notifier.state = next;
  }
}

/// [messages] without those whose authors are in [blockedUserIds].
List<Message> withoutBlockedAuthors(
  List<Message> messages,
  Set<String> blockedUserIds,
) {
  if (blockedUserIds.isEmpty) return messages;
  return messages
      .where((message) => !blockedUserIds.contains(message.userId))
      .toList();
}

/// Whether the server says this socket isn't in a room (it lost track of the
/// room, e.g. after a reconnect). Matched by code; the text is a fallback for
/// older backends.
bool isNotInRoomError(SocketErrorData error) {
  return error.code == SocketService.notInRoomCode ||
      error.message.contains('Not in a room');
}

Message _withReplyCount(Message message, int replyCount) {
  return Message(
    id: message.id,
    roomId: message.roomId,
    userId: message.userId,
    username: message.username,
    text: message.text,
    createdAt: message.createdAt,
    parentMessageId: message.parentMessageId,
    replyCount: replyCount,
  );
}

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
  dynamic _removedHandler;

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
      if (!mounted) return;
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

      // Moderation: drop a removed reply, or close the thread if its parent
      // message was removed.
      _removedHandler = socketService.addListener('message_removed', (data) {
        final removedId = data['messageId']?.toString();
        if (removedId == null) return;

        if (removedId == messageId) {
          ref.read(threadParentRemovedProvider(messageId).notifier).state =
              true;
          return;
        }

        final currentState = state.value;
        if (currentState == null) return;

        final filtered =
            currentState.replies.where((r) => r.id != removedId).toList();
        if (filtered.length != currentState.replies.length) {
          state = AsyncValue.data(
            ThreadData(
              parentMessage: currentState.parentMessage,
              replies: filtered,
            ),
          );
        }
      });
    } catch (e, stack) {
      if (!mounted) return;
      state = AsyncValue.error(e, stack);
    }
  }

  @override
  void dispose() {
    if (_socketHandler != null) {
      socketService.removeListener('new_message', _socketHandler);
    }
    if (_removedHandler != null) {
      socketService.removeListener('message_removed', _removedHandler);
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
  static const _rejoinTimeout = Duration(seconds: 5);

  final Ref ref;
  final Room room;
  final SocketService socketService;
  bool _isInitialized = false;
  bool _disposed = false;

  // Store handler references returned from socketService so we can remove only our specific listeners
  dynamic _roomJoinedHandler;
  dynamic _newMessageHandler;
  dynamic _messageRemovedHandler;
  dynamic _errorHandler;

  // Surfaces user-facing socket errors that aren't about a send (those are
  // returned by sendMessage) to the page, which shows them as a toast.
  final StreamController<String> _errorMessages =
      StreamController<String>.broadcast();
  Stream<String> get errorMessages => _errorMessages.stream;

  // The server reports a failed send twice: as an 'error' event and in the
  // acknowledgement right after it. While a send is waiting for its
  // acknowledgement, error events are held back and dropped if the
  // acknowledgement reports the same failure.
  int _pendingSends = 0;
  final List<SocketErrorData> _heldErrors = [];

  Completer<void>? _roomJoined;

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
      ref.read(roomMessagesProvider(roomId).notifier).state =
          joinedData.messages;

      state = state.copyWith(
        isInitialLoading: false,
        hasMore: joinedData.hasMore,
        nextCursor: joinedData.nextCursor,
        lastReadAt: joinedData.lastReadAt,
      );

      final joined = _roomJoined;
      if (joined != null && !joined.isCompleted) {
        joined.complete();
      }
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
            return _withReplyCount(msg, msg.replyCount + 1);
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

    // Register message_removed listener (moderation): drop the message live.
    _messageRemovedHandler =
        socketService.addListener('message_removed', (data) {
      if (_disposed) return;

      final removedId = data['messageId']?.toString();
      final eventRoomId = data['roomId']?.toString();
      if (removedId == null || eventRoomId != roomId) return;

      final currentMessages = ref.read(roomMessagesProvider(roomId));
      var updated = currentMessages.where((m) => m.id != removedId).toList();

      // A removed reply lowers its parent's reply count. Replies aren't in
      // this list, so the parent comes from the event.
      final parentId = data['parentMessageId']?.toString();
      if (parentId != null && parentId.isNotEmpty) {
        updated = updated.map((msg) {
          if (msg.id == parentId && msg.replyCount > 0) {
            return _withReplyCount(msg, msg.replyCount - 1);
          }
          return msg;
        }).toList();
      }

      ref.read(roomMessagesProvider(roomId).notifier).state = updated;
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

      if (_pendingSends > 0) {
        _heldErrors.add(socketError);
        return;
      }
      _handleSocketError(socketError);
    });
  }

  void _handleSocketError(SocketErrorData socketError) {
    if (_disposed) return;

    // If "Not in a room" error, try to rejoin
    if (isNotInRoomError(socketError)) {
      if (kDebugMode) {
        print('Attempting to rejoin room...');
      }
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_disposed) _joinRoom(force: true);
      });
      return;
    }

    if (!_errorMessages.isClosed) {
      _errorMessages.add(socketError.message);
    }
  }

  void _joinRoom({bool force = false}) {
    // SocketService already tracks the latest token via socketServiceProvider.
    // Joining should always use that latest token.
    socketService.joinRoom(room, force: force);
  }

  /// Sends [text] and reports whether the server stored it, so the page can
  /// keep the draft (and show why) when it didn't.
  Future<SendMessageResult> sendMessage(
    String text, {
    String? parentMessageId,
  }) async {
    _pendingSends++;
    try {
      var result = await socketService.sendMessage(
        text,
        parentMessageId: parentMessageId,
      );
      _dropHeldError(result.error);

      final error = result.error;
      if (error != null && isNotInRoomError(error) && !_disposed) {
        // The server lost track of the room: rejoin and try once more.
        if (await _rejoin()) {
          result = await socketService.sendMessage(
            text,
            parentMessageId: parentMessageId,
          );
          _dropHeldError(result.error);
        }
      }
      return result;
    } finally {
      _pendingSends--;
      if (_pendingSends == 0 && _heldErrors.isNotEmpty) {
        // Errors that weren't about the send after all.
        final errors = List.of(_heldErrors);
        _heldErrors.clear();
        errors.forEach(_handleSocketError);
      }
    }
  }

  void _dropHeldError(SocketErrorData? failure) {
    if (failure == null) return;
    final index = _heldErrors.indexWhere(
      (held) => held.code == failure.code && held.message == failure.message,
    );
    if (index >= 0) {
      _heldErrors.removeAt(index);
    }
  }

  /// Rejoins the room and waits for the server to confirm. Sends that fail
  /// at the same time share one rejoin.
  Future<bool> _rejoin() async {
    var joined = _roomJoined;
    if (joined == null) {
      joined = Completer<void>();
      _roomJoined = joined;
      _joinRoom(force: true);
    }
    try {
      await joined.future.timeout(_rejoinTimeout);
      return true;
    } on TimeoutException {
      return false;
    } finally {
      if (identical(_roomJoined, joined)) {
        _roomJoined = null;
      }
    }
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
    if (_messageRemovedHandler != null) {
      socketService.removeListener('message_removed', _messageRemovedHandler);
    }
    if (_errorHandler != null) {
      socketService.removeListener('error', _errorHandler);
    }

    _errorMessages.close();

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
