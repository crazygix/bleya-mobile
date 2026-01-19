import '../entities/message.dart';

/// Domain repository interface for message operations
/// Use cases depend on this interface, not concrete implementations
abstract class MessageRepository {
  Future<ThreadData> getThread(String messageId);
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
