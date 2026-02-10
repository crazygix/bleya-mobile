import '../../domain/repositories/message_repository.dart';

class GetRoomMessagesPageUseCase {
  final MessageRepository _messageRepository;

  GetRoomMessagesPageUseCase(this._messageRepository);

  Future<RoomMessagesPage> call(
    String roomId, {
    int? before,
    int? limit,
  }) {
    return _messageRepository.getRoomMessagesPage(
      roomId,
      before: before,
      limit: limit,
    );
  }
}

