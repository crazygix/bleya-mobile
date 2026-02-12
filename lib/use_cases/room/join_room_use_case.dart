import '../../domain/entities/room.dart';
import '../../domain/repositories/room_repository.dart';

class JoinRoomUseCase {
  final RoomRepository _roomRepository;

  JoinRoomUseCase(this._roomRepository);

  Future<Room> call(String roomId) async {
    return await _roomRepository.joinRoom(roomId);
  }
}
