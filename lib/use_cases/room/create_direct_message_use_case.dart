import '../../domain/entities/room.dart';
import '../../domain/repositories/room_repository.dart';

class CreateDirectMessageUseCase {
  final RoomRepository _roomRepository;

  CreateDirectMessageUseCase(this._roomRepository);

  Future<Room> call(String otherUserId) async {
    return await _roomRepository.createDirectMessage(otherUserId);
  }
}
