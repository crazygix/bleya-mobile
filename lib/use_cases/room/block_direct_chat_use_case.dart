import '../../domain/entities/direct_chat_status.dart';
import '../../domain/repositories/room_repository.dart';

class BlockDirectChatUseCase {
  final RoomRepository _roomRepository;

  BlockDirectChatUseCase(this._roomRepository);

  Future<DirectChatActionResult> call(String otherUserId) async {
    return await _roomRepository.blockDirectChat(otherUserId);
  }
}
