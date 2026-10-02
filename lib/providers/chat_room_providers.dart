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

/// Users blocked during this session (recordBlockChange). Their messages
/// already on screen are hidden straight away; the server stops sending new
/// ones.
final sessionBlockedUserIdsProvider = StateProvider<Set<String>>((ref) {
  ref.watch(sessionVersionProvider);
  return const <String>{};
});

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

  /// Why the room couldn't be opened (the server's reason, or a connection
  /// problem), until it opens.
  final String? joinError;

  // Sentinel used in copyWith so we can distinguish
  // "parameter not provided" from "explicitly set to null".
  static const Object _notProvided = Object();

  const ChatRoomState({
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.nextCursor,
    required this.lastReadAt,
    this.joinError,
  });

  const ChatRoomState.initial()
      : isInitialLoading = true,
        isLoadingMore = false,
        hasMore = false,
        nextCursor = null,
        lastReadAt = null,
        joinError = null;

  ChatRoomState copyWith({
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? nextCursor = _notProvided,
    Object? lastReadAt = _notProvided,
    Object? joinError = _notProvided,
  }) {
    return ChatRoomState(
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: identical(nextCursor, _notProvided)
          ? this.nextCursor
          : nextCursor as String?,
      lastReadAt: identical(lastReadAt, _notProvided)
          ? this.lastReadAt
          : lastReadAt as DateTime?,
      joinError: identical(joinError, _notProvided)
          ? this.joinError
          : joinError as String?,
    );
  }
}

/// Orders messages as the server pages them: by time, then by id.
int _compareMessageOrder(Message a, Message b) {
  final byTime = a.createdAt.compareTo(b.createdAt);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

/// Merges [latest], the newest page of a room as room_joined sends it, into
/// the [loaded] messages (both oldest first) and their paging state.
///
/// The page is authoritative from its oldest message on, so messages removed
/// or blocked meanwhile drop out. Where the page reaches back to what's
/// loaded, the older messages and their cursor stay. Where there may be a
/// gap between them, or the page is the whole room, the page replaces the
/// list.
RoomMessagesPage mergeLatestPage(
  RoomMessagesPage loaded,
  RoomMessagesPage latest,
) {
  if (loaded.messages.isEmpty ||
      latest.messages.isEmpty ||
      !latest.hasMore ||
      _compareMessageOrder(latest.messages.first, loaded.messages.last) > 0) {
    return latest;
  }

  final windowStart = latest.messages.first;
  final older = loaded.messages
      .where((message) => _compareMessageOrder(message, windowStart) < 0)
      .toList();
  if (older.isEmpty) {
    return latest;
  }
  return RoomMessagesPage(
    messages: [...older, ...latest.messages],
    hasMore: loaded.hasMore,
    nextCursor: loaded.nextCursor,
  );
}

/// The [live] messages that [page] (oldest first) doesn't have and that are
/// newer than its newest message: stored after the page was built.
List<Message> _newerThanPage(List<Message> live, List<Message> page) {
  final pageIds = {for (final message in page) message.id};
  return live
      .where((message) =>
          !pageIds.contains(message.id) &&
          (page.isEmpty || _compareMessageOrder(message, page.last) > 0))
      .toList();
}

/// A thread's parent and replies, kept live from the socket. It listens
/// before its first fetch, and fetches again whenever the socket joins the
/// thread's room again, since replies sent while the socket was away never
/// arrive as events.
class ThreadController extends StateNotifier<AsyncValue<ThreadData>> {
  final Ref ref;
  final String messageId;
  final SocketService socketService;
  dynamic _newMessageHandler;
  dynamic _removedHandler;
  dynamic _roomJoinedHandler;

  bool _isFetching = false;
  bool _refetchQueued = false;
  // Replies and removals that arrive while a fetch runs, applied to its
  // result: the server may have answered before or after them.
  final Map<String, Message> _repliesDuringFetch = {};
  final Set<String> _removedDuringFetch = {};
  // Rooms joined during the first fetch, before the thread's room is known.
  final Set<String> _roomsJoinedDuringFirstFetch = {};

  ThreadController(this.ref, this.messageId, this.socketService)
      : super(const AsyncValue.loading()) {
    _newMessageHandler =
        socketService.addListener('new_message', _onNewMessage);
    _removedHandler =
        socketService.addListener('message_removed', _onMessageRemoved);
    _roomJoinedHandler =
        socketService.addListener('room_joined', _onRoomJoined);
    _fetch();
  }

  Future<void> _fetch() async {
    if (_isFetching) {
      _refetchQueued = true;
      return;
    }
    _isFetching = true;
    _repliesDuringFetch.clear();
    _removedDuringFetch.clear();

    try {
      final getThreadUseCase = ref.read(getThreadUseCaseProvider);
      final threadData = await getThreadUseCase(messageId);
      if (!mounted) return;

      final replies = threadData.replies
          .where((reply) => !_removedDuringFetch.contains(reply.id))
          .toList();
      final fetchedIds = replies.map((reply) => reply.id).toSet();
      replies.addAll(
        _repliesDuringFetch.values
            .where((reply) => !fetchedIds.contains(reply.id)),
      );

      final isFirstFetch = !state.hasValue;
      state = AsyncValue.data(
        ThreadData(parentMessage: threadData.parentMessage, replies: replies),
      );
      if (isFirstFetch &&
          _roomsJoinedDuringFirstFetch
              .contains(threadData.parentMessage.roomId)) {
        // The room was joined while the thread loaded: replies sent before
        // the join may have missed both the fetch and the socket.
        _refetchQueued = true;
      }
    } catch (e, stack) {
      if (!mounted) return;
      // A failed refetch keeps the replies on screen.
      if (!state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
    } finally {
      _isFetching = false;
      _repliesDuringFetch.clear();
      _removedDuringFetch.clear();
      _roomsJoinedDuringFirstFetch.clear();
      if (_refetchQueued && mounted) {
        _refetchQueued = false;
        unawaited(_fetch());
      }
    }
  }

  void _onNewMessage(Map<String, dynamic> data) {
    final message = socketService.parseMessagePayload(data);
    if (message == null || message.parentMessageId != messageId) {
      return;
    }
    if (_isFetching) {
      _repliesDuringFetch[message.id] = message;
    }

    final currentState = state.valueOrNull;
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
  }

  // Moderation: drop a removed reply, or close the thread if its parent
  // message was removed.
  void _onMessageRemoved(Map<String, dynamic> data) {
    final removedId = data['messageId']?.toString();
    if (removedId == null) return;

    if (removedId == messageId) {
      ref.read(threadParentRemovedProvider(messageId).notifier).state = true;
      return;
    }

    if (_isFetching) {
      _removedDuringFetch.add(removedId);
      _repliesDuringFetch.remove(removedId);
    }

    final currentState = state.valueOrNull;
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
  }

  void _onRoomJoined(Map<String, dynamic> data) {
    final rawRoom = data['room'];
    final roomId = rawRoom is Map ? rawRoom['id']?.toString() : null;
    if (roomId == null) return;

    final currentState = state.valueOrNull;
    if (currentState == null) {
      if (_isFetching) {
        _roomsJoinedDuringFirstFetch.add(roomId);
      }
      return;
    }
    if (roomId == currentState.parentMessage.roomId) {
      unawaited(_fetch());
    }
  }

  @override
  void dispose() {
    socketService.removeListener('new_message', _newMessageHandler);
    socketService.removeListener('message_removed', _removedHandler);
    socketService.removeListener('room_joined', _roomJoinedHandler);
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

/// A chat room's messages, paging and live updates. Which room the socket is
/// in is up to the screens' claims in [SocketService]; this controller only
/// listens.
class ChatRoomController extends StateNotifier<ChatRoomState> {
  // Shown when a room_joined for this room can't be read.
  static const _unreadableRoomMessage =
      "We couldn't open that chat. Please try again.";

  final Ref ref;
  final Room room;
  final SocketService socketService;
  bool _disposed = false;

  // Store handler references returned from socketService so we can remove only our specific listeners
  dynamic _roomJoinedHandler;
  dynamic _newMessageHandler;
  dynamic _messageRemovedHandler;
  dynamic _errorHandler;
  StreamSubscription<RoomJoinFailure>? _joinFailureSubscription;

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

  ChatRoomController(this.ref, this.room, this.socketService)
      : super(const ChatRoomState.initial()) {
    _setupSocketListeners();
  }

  String get roomId => room.id;

  void _setupSocketListeners() {
    _roomJoinedHandler =
        socketService.addListener('room_joined', _onRoomJoined);

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
        // Already listed, e.g. in the page room_joined brought just before.
        if (currentMessages.any((existing) => existing.id == message.id)) {
          return;
        }
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

    _joinFailureSubscription =
        socketService.joinFailures.listen(_onJoinFailure);
  }

  void _onRoomJoined(Map<String, dynamic> data) {
    // Ignore events if this controller has been disposed
    if (_disposed) return;

    final joinedData = socketService.parseRoomJoinedPayload(data);
    if (joinedData == null) {
      // A page for this room that can't be read would leave the chat
      // loading forever: show the error state instead.
      final rawRoom = data['room'];
      if (rawRoom is Map && rawRoom['id']?.toString() == roomId) {
        state = state.copyWith(
          isInitialLoading: false,
          joinError: _unreadableRoomMessage,
        );
      }
      return;
    }
    if (joinedData.room.id != roomId) return;

    final messages = ref.read(roomMessagesProvider(roomId).notifier);
    final loaded = messages.state;
    final merged = mergeLatestPage(
      RoomMessagesPage(
        messages: loaded,
        hasMore: state.hasMore,
        nextCursor: state.nextCursor,
      ),
      RoomMessagesPage(
        messages: joinedData.messages,
        hasMore: joinedData.hasMore,
        nextCursor: joinedData.nextCursor,
      ),
    );
    // Before its first page, the screen lists only messages that came live.
    // When the socket was already in the room for another screen, the server
    // sends those stored while it builds the page, which doesn't have them.
    messages.state = state.isInitialLoading
        ? [...merged.messages, ..._newerThanPage(loaded, joinedData.messages)]
        : merged.messages;

    state = state.copyWith(
      isInitialLoading: false,
      hasMore: merged.hasMore,
      nextCursor: merged.nextCursor,
      lastReadAt: joinedData.lastReadAt,
      joinError: null,
    );
  }

  void _onJoinFailure(RoomJoinFailure failure) {
    if (_disposed || failure.roomId != roomId) return;

    state = state.copyWith(
      isInitialLoading: false,
      joinError: failure.error.message,
    );
    // With messages on screen the error state doesn't show, so say why the
    // chat isn't live when the server refused it.
    if (failure.isRefusal &&
        ref.read(roomMessagesProvider(roomId)).isNotEmpty) {
      _showError(failure.error.message);
    }
  }

  void _handleSocketError(SocketErrorData socketError) {
    if (_disposed) return;

    // SocketService rejoins the chat on screen by itself.
    if (SocketService.isNotInRoomError(socketError)) return;

    _showError(socketError.message);
  }

  void _showError(String message) {
    // The socket is shared: its errors concern the chat on screen, so a
    // screen lower in the stack stays quiet.
    if (socketService.openChat.value.roomId != roomId) return;
    if (!_errorMessages.isClosed) {
      _errorMessages.add(message);
    }
  }

  /// Gets the room's messages for a screen that just opened, also when the
  /// socket is already in the room for another screen.
  void ensureLoaded() {
    if (state.isInitialLoading) {
      socketService.requestRoomSnapshot(room);
    }
  }

  /// Tries to open the room again after it failed (Try again).
  void retryJoin() {
    state = state.copyWith(isInitialLoading: true, joinError: null);
    socketService.retryJoin(room);
  }

  /// Sends [text] and reports whether the server stored it, so the page can
  /// keep the draft (and show why) when it didn't. SocketService retries
  /// once when the room has to be joined again first.
  Future<SendMessageResult> sendMessage(
    String text, {
    String? parentMessageId,
  }) async {
    _pendingSends++;
    try {
      final result = await socketService.sendMessage(
        text,
        room: room,
        parentMessageId: parentMessageId,
      );
      _dropHeldError(result.error);
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

      if (state.nextCursor != currentCursor) {
        // A room_joined replaced the list meanwhile: this page no longer
        // joins up with it.
        state = state.copyWith(isLoadingMore: false);
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
    _joinFailureSubscription?.cancel();

    _errorMessages.close();

    // The screens release their claims on the room themselves.
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
