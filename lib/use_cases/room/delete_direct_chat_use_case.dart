import '../../domain/entities/direct_chat_status.dart';
import '../../domain/repositories/room_repository.dart';

class DeleteDirectChatUseCase {
  final RoomRepository _roomRepository;

  DeleteDirectChatUseCase(this._roomRepository);

  Future<DirectChatActionResult> call(String otherUserId) async {
    return await _roomRepository.deleteDirectChat(otherUserId);
  }
}
