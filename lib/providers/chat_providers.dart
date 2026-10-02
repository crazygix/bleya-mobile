import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
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

/// A room_summary_updated event to apply to the list being fetched, and the
/// unread message it adds.
class _SummaryDuringFetch {
  _SummaryDuringFetch(this.roomId, this.payload, this.unreadIncrement);

  final String roomId;
  final Map<String, dynamic> payload;
  int unreadIncrement;
}

/// Controller for the rooms list on the dashboard, including realtime updates
/// from the socket and per-session unread counts.
class RoomsListController
    extends StateNotifier<AsyncValue<List<RoomListItem>>> {
  final Ref ref;
  final SocketService socketService;

  // How long the list waits after a removed preview before loading again,
  // so the removals of one moderation action load it once.
  static const _removalRefreshDelay = Duration(milliseconds: 500);

  bool _hasLoggedUnreadFallback = false;
  dynamic _roomSummaryHandler;
  dynamic _messageRemovedHandler;
  Timer? _removalRefresh;
  StreamSubscription<void>? _resyncSubscription;

  // One fetch of the list runs at a time. refresh() calls made during it
  // share one more fetch after it, so none of them is dropped.
  bool _isFetching = false;
  Completer<void>? _nextFetch;
  // What changed while the list was being fetched, applied to the result
  // too: the server may have answered before or after it.
  final List<_SummaryDuringFetch> _summariesDuringFetch = [];
  final Set<String> _readDuringFetch = {};

  RoomsListController(this.ref, this.socketService)
      : super(const AsyncValue.loading()) {
    _initialize();
  }

  void _initialize() {
    final token = ref.read(tokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    // Events sent while the socket was away never arrive, so the list
    // catches up whenever the socket asks.
    _resyncSubscription = socketService.resyncRequests.listen((_) {
      unawaited(refresh());
    });
    unawaited(refresh());
  }

  void _onRoomSummaryUpdated(Map<String, dynamic> data) {
    final roomId = data['roomId']?.toString();
    if (roomId == null || roomId.isEmpty) return;

    final openRoomId = socketService.openChat.value.roomId;
    final currentUser = ref.read(currentUserProvider);
    final currentUserId = currentUser?['id']?.toString();
    final messageUserId = data['lastMessageUserId']?.toString();
    final isOwnMessage =
        currentUserId != null && messageUserId == currentUserId;
    final unreadIncrement = (openRoomId == roomId || isOwnMessage) ? 0 : 1;

    final current = state.valueOrNull;
    final isListed =
        current != null && current.any((item) => item.room.id == roomId);
    if (_isFetching || !isListed) {
      // Also applied to the result of the fetch running now, or of the one
      // started for it below.
      _summariesDuringFetch.add(
        _SummaryDuringFetch(roomId, data, unreadIncrement),
      );
      if (!isListed && (current != null || !_isFetching)) {
        // A chat the list doesn't show yet, such as a new one, or a list
        // that didn't load: fetch the list, once more if a fetch is running.
        unawaited(refresh());
      }
    }
    if (current == null || !isListed) return;

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

  /// Listens for the socket events that change the list, once.
  void _listen() {
    _roomSummaryHandler = socketService.addListener(
      'room_summary_updated',
      _onRoomSummaryUpdated,
    );
    _messageRemovedHandler = socketService.addListener(
      'message_removed',
      _onMessageRemoved,
    );
  }

  /// A moderator removed a message. If a chat may show it as its preview,
  /// the list loads again: the new preview is the latest message this user
  /// can see, which only the server knows. One action can remove many
  /// messages, one event each, so the list loads once, after the last.
  void _onMessageRemoved(Map<String, dynamic> data) {
    final removal = socketService.parseMessageRemovedPayload(data);
    // A reply is never a chat's preview.
    if (removal == null || removal.parentMessageId != null) return;
    // A list on its way may still have it, even for a chat not listed yet.
    if (!_isFetching && !_mayShowAsPreview(removal)) return;

    _removalRefresh?.cancel();
    _removalRefresh = Timer(_removalRefreshDelay, () {
      _removalRefresh = null;
      unawaited(refresh());
    });
  }

  /// Whether the list may show [removal] as its chat's preview. Without the
  /// message's author and time (older backends), any listed chat in its room
  /// may.
  bool _mayShowAsPreview(MessageRemovedEventData removal) {
    final items = state.valueOrNull ?? const <RoomListItem>[];
    for (final item in items) {
      final room = item.room;
      if (room.id != removal.roomId) continue;

      final sentAt = removal.createdAt;
      final shownAt = room.lastMessageTime;
      if (sentAt != null &&
          shownAt != null &&
          !sentAt.isAtSameMomentAs(shownAt)) {
        return false;
      }
      final authorId = removal.userId;
      final shownAuthorId = room.lastMessageUserId;
      return authorId == null ||
          shownAuthorId == null ||
          authorId == shownAuthorId;
    }
    return false;
  }

  /// Fetches the list again, with the server's unread counts. A call made
  /// while a fetch runs is served by one more fetch after it.
  Future<void> refresh() {
    if (_isFetching) {
      return (_nextFetch ??= Completer<void>()).future;
    }
    return _fetchWhileAsked();
  }

  Future<void> _fetchWhileAsked() async {
    _isFetching = true;
    try {
      await _fetch();
      while (mounted) {
        final next = _nextFetch;
        if (next == null) break;
        _nextFetch = null;
        try {
          await _fetch();
        } finally {
          next.complete();
        }
      }
    } finally {
      _isFetching = false;
      // Disposed meanwhile: no fetch is coming for those still waiting.
      _nextFetch?.complete();
      _nextFetch = null;
    }
  }

  Future<void> _fetch() async {
    try {
      if (_roomSummaryHandler == null) {
        // Per-user events like room_summary_updated need the socket.
        await socketService.ensureConnectedForUserChannel();
        // Disposed meanwhile (the session changed): register nothing.
        if (!mounted) return;
        _listen();
      }

      final getJoinedRoomsUseCase = ref.read(getJoinedRoomsUseCaseProvider);
      final rooms = await getJoinedRoomsUseCase();
      if (!mounted) return;

      state = AsyncValue.data(
        _withChangesDuringFetch(_itemsFromServer(rooms)),
      );
    } catch (e, stack) {
      if (kDebugMode) {
        print('Error loading joined rooms: $e');
      }
      // A list on screen stays, with what arrived meanwhile already on it.
      if (!mounted || state.hasValue) return;
      state = AsyncValue.error(e, stack);
      // Load again once the socket connects, e.g. after an offline start.
      socketService.requestResyncOnConnect();
    } finally {
      _summariesDuringFetch.clear();
      _readDuringFetch.clear();
    }
  }

  /// [rooms] as the server sent them, with its unread counts. The open room
  /// counts as read.
  List<RoomListItem> _itemsFromServer(List<Room> rooms) {
    final openRoomId = socketService.openChat.value.roomId;
    final shownUnreadByRoomId = <String, int>{
      for (final item in state.valueOrNull ?? const <RoomListItem>[])
        item.room.id: item.unreadCount,
    };
    return [
      for (final room in rooms)
        RoomListItem(
          room: room,
          unreadCount: room.id == openRoomId
              ? 0
              : _serverUnreadForRoom(room, shownUnreadByRoomId[room.id]),
        ),
    ];
  }

  /// [items] with the rooms read and the summaries received during the
  /// fetch.
  List<RoomListItem> _withChangesDuringFetch(List<RoomListItem> items) {
    var updated = [
      for (final item in items)
        _readDuringFetch.contains(item.room.id)
            ? item.copyWith(unreadCount: 0)
            : item,
    ];
    for (final summary in _summariesDuringFetch) {
      updated = _applySummaryUpdate(
        updated,
        roomId: summary.roomId,
        payload: summary.payload,
        unreadIncrement: summary.unreadIncrement,
      );
    }
    _sortByLastMessageTime(updated);
    return updated;
  }

  /// The server's unread count for [room]. Older backends don't send one:
  /// then the count [shown] stays, or one unread is assumed when someone
  /// else sent the last message.
  int _serverUnreadForRoom(Room room, int? shown) {
    if (room.hasUnreadCount) {
      return room.unreadCount;
    }

    if (!_hasLoggedUnreadFallback && kDebugMode) {
      _hasLoggedUnreadFallback = true;
      print('rooms/joined missing unreadCount; using last-message fallback');
    }
    if (shown != null) {
      return shown;
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

  /// [source] with [payload] as [roomId]'s latest message. A summary that
  /// isn't newer than the room's last message is already counted, e.g. by a
  /// fetch that answered after it, so it changes nothing.
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

    final summaryTime = _parseTimestamp(payload['lastMessageTime']);
    final shownTime = existingRoom.lastMessageTime;
    if (summaryTime != null &&
        shownTime != null &&
        !summaryTime.isAfter(shownTime)) {
      return source;
    }

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

    final openRoomId = socketService.openChat.value.roomId;
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

  /// Marks [roomId] as read: on the server right away, even while the list
  /// loads, and in the list once it's there.
  void markRoomAsRead(String roomId) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data([
        for (final item in current)
          item.room.id == roomId ? item.copyWith(unreadCount: 0) : item,
      ]);
    }
    if (_isFetching) {
      // The list on its way may have been counted before this.
      _readDuringFetch.add(roomId);
      for (final summary in _summariesDuringFetch) {
        if (summary.roomId == roomId) {
          summary.unreadIncrement = 0;
        }
      }
    }

    // The server counts what's after this as unread, and so does the list
    // when it loads next.
    unawaited(_postRead(roomId));
  }

  Future<void> _postRead(String roomId) async {
    try {
      await ref.read(markRoomAsReadUseCaseProvider)(roomId);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to mark room $roomId as read on backend: $e');
      }
    }
  }

  @override
  void dispose() {
    _resyncSubscription?.cancel();
    _removalRefresh?.cancel();
    if (_roomSummaryHandler != null) {
      socketService.removeListener(
        'room_summary_updated',
        _roomSummaryHandler,
      );
    }
    if (_messageRemovedHandler != null) {
      socketService.removeListener('message_removed', _messageRemovedHandler);
    }
    // No fetch is coming for those still waiting.
    _nextFetch?.complete();
    _nextFetch = null;
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

/// Keeps each room's read position on the server current, so the unread
/// counts the chat list loads are right. Whenever the open chat changes, it
/// marks read both the room that stopped being visible and the one that
/// became visible. It also marks the open room read when the app goes
/// inactive, which comes first when the app goes to the background or is
/// closed from the iOS app switcher. The dashboard keeps it alive.
final roomReadSyncProvider = Provider<void>((ref) {
  ref.watch(sessionVersionProvider);
  final socketService = ref.read(socketServiceProvider);
  var visibleRoomId = socketService.openChat.value.roomId;

  void markRead(String roomId) {
    final token = ref.read(tokenProvider);
    // Signed out: there's no read position to keep.
    if (token == null || token.isEmpty) return;
    ref.read(roomsListProvider.notifier).markRoomAsRead(roomId);
  }

  void onOpenChatChanged() {
    final roomId = socketService.openChat.value.roomId;
    if (roomId == visibleRoomId) return;
    final previousRoomId = visibleRoomId;
    visibleRoomId = roomId;
    if (previousRoomId != null) {
      markRead(previousRoomId);
    }
    if (roomId != null) {
      markRead(roomId);
    }
  }

  socketService.openChat.addListener(onOpenChatChanged);
  final lifecycle = AppLifecycleListener(
    onInactive: () {
      final roomId = visibleRoomId;
      if (roomId != null) {
        markRead(roomId);
      }
    },
  );
  ref.onDispose(() {
    socketService.openChat.removeListener(onOpenChatChanged);
    lifecycle.dispose();
  });
});

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

    // The user left: no screen may keep the socket in the room, or a
    // reconnect would join it again before those screens close.
    ref.read(socketServiceProvider).releaseRoom(roomId);

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

/// Blocks [otherUserId] from the direct chat. The caller records the block
/// with recordBlockChange, which also loads the chat list again.
Future<DirectChatActionResult> blockDirectChat(
  WidgetRef ref,
  String otherUserId,
) async {
  try {
    final useCase = ref.read(blockDirectChatUseCaseProvider);
    final result = await useCase(otherUserId);

    ref.invalidate(joinedRoomsFutureProvider);

    return result;
  } catch (e) {
    if (kDebugMode) {
      print('Error blocking direct chat: $e');
    }
    rethrow;
  }
}

/// Unblocks [otherUserId] in the direct chat. The caller records the
/// unblock with recordBlockChange, which also loads the chat list again.
Future<DirectChatActionResult> unblockDirectChat(
  WidgetRef ref,
  String otherUserId,
) async {
  try {
    final useCase = ref.read(unblockDirectChatUseCaseProvider);
    final result = await useCase(otherUserId);

    ref.invalidate(joinedRoomsFutureProvider);

    return result;
  } catch (e) {
    if (kDebugMode) {
      print('Error unblocking direct chat: $e');
    }
    rethrow;
  }
}
