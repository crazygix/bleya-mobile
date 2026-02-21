import '../../domain/entities/direct_chat_status.dart';
import '../../domain/repositories/room_repository.dart';

class GetDirectChatStatusUseCase {
  final RoomRepository _roomRepository;

  GetDirectChatStatusUseCase(this._roomRepository);

  Future<DirectChatStatus> call(String otherUserId) async {
    return await _roomRepository.getDirectChatStatus(otherUserId);
  }
}
