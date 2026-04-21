import '../../domain/entities/room.dart';
import '../../domain/repositories/room_repository.dart';

class GetRoomUseCase {
  final RoomRepository _roomRepository;

  GetRoomUseCase(this._roomRepository);

  Future<Room> call(String roomId) async {
    return await _roomRepository.getRoom(roomId);
  }
}
