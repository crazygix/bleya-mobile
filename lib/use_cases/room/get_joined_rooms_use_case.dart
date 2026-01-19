import '../../domain/entities/room.dart';
import '../../domain/repositories/room_repository.dart';

class GetJoinedRoomsUseCase {
  final RoomRepository _roomRepository;

  GetJoinedRoomsUseCase(this._roomRepository);

  Future<List<Room>> call() async {
    return await _roomRepository.getJoinedRooms();
  }
}
