import '../../domain/entities/message.dart';
import '../../domain/entities/room.dart';
import '../../domain/repositories/message_repository.dart';
import '../../domain/repositories/room_repository.dart';

class NotificationThreadContext {
  final Room room;
  final Message parentMessage;

  const NotificationThreadContext({
    required this.room,
    required this.parentMessage,
  });
}

class GetNotificationThreadContextUseCase {
  final RoomRepository _roomRepository;
  final MessageRepository _messageRepository;

  GetNotificationThreadContextUseCase(
    this._roomRepository,
    this._messageRepository,
  );

  Future<NotificationThreadContext> call({
    required String roomId,
    required String threadId,
  }) async {
    final results = await Future.wait<Object>([
      _roomRepository.getRoom(roomId),
      _messageRepository.getMessage(threadId),
    ]);

    return NotificationThreadContext(
      room: results[0] as Room,
      parentMessage: results[1] as Message,
    );
  }
}
