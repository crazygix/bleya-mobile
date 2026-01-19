import '../../domain/entities/room.dart';
import '../../domain/repositories/room_repository.dart';

class GetAvailableRoomsUseCase {
  final RoomRepository _roomRepository;

  GetAvailableRoomsUseCase(this._roomRepository);

  Future<List<Room>> call() async {
    return await _roomRepository.getAvailableRooms();
  }
}
