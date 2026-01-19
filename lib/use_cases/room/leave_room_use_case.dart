import '../../domain/repositories/room_repository.dart';

class LeaveRoomUseCase {
  final RoomRepository _roomRepository;

  LeaveRoomUseCase(this._roomRepository);

  Future<void> call(String roomId) async {
    await _roomRepository.leaveRoom(roomId);
  }
}
