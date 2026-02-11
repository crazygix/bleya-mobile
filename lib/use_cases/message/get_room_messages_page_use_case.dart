import '../../domain/repositories/message_repository.dart';

class GetRoomMessagesPageUseCase {
  final MessageRepository _messageRepository;

  GetRoomMessagesPageUseCase(this._messageRepository);

  Future<RoomMessagesPage> call(
    String roomId, {
    String? before,
    int? limit,
  }) {
    return _messageRepository.getRoomMessagesPage(
      roomId,
      before: before,
      limit: limit,
    );
  }
}

class MarkRoomAsReadUseCase {
  final MessageRepository _messageRepository;

  MarkRoomAsReadUseCase(this._messageRepository);

  Future<int> call(String roomId) {
    return _messageRepository.markRoomAsRead(roomId);
  }
}
