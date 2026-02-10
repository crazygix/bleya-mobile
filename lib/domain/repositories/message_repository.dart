import '../entities/message.dart';

/// Domain model for a page of room messages (top-level only).
class RoomMessagesPage {
  final List<Message> messages;
  final bool hasMore;

  /// Cursor representing the timestamp (milliseconds since epoch) of the oldest
  /// message in this page. Pass this as `before` to load older history.
  final int? nextCursor;

  RoomMessagesPage({
    required this.messages,
    required this.hasMore,
    required this.nextCursor,
  });
}

/// Domain model for thread data
class ThreadData {
  final Message parentMessage;
  final List<Message> replies;

  ThreadData({
    required this.parentMessage,
    required this.replies,
  });
}

/// Domain repository interface for message operations
/// Use cases depend on this interface, not concrete implementations
abstract class MessageRepository {
  Future<ThreadData> getThread(String messageId);

  /// Load a page of top-level messages for a room.
  ///
  /// - [roomId]: ID of the room.
  /// - [before]: optional cursor (milliseconds since epoch) to load messages
  ///   strictly older than this timestamp.
  /// - [limit]: optional page size override (backend enforces an upper bound).
  Future<RoomMessagesPage> getRoomMessagesPage(
    String roomId, {
    int? before,
    int? limit,
  });

  /// Mark all messages in a room as read for the current user.
  ///
  /// Backend will update the per-room read pointer and return the effective
  /// lastReadAt timestamp (milliseconds since epoch).
  Future<int> markRoomAsRead(String roomId);
}
