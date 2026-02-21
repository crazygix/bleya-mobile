import '../../domain/entities/direct_chat_status.dart';
import '../../domain/repositories/room_repository.dart';

class UnblockDirectChatUseCase {
  final RoomRepository _roomRepository;

  UnblockDirectChatUseCase(this._roomRepository);

  Future<DirectChatActionResult> call(String otherUserId) async {
    return await _roomRepository.unblockDirectChat(otherUserId);
  }
}
