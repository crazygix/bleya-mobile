import '../../domain/entities/room_member.dart';
import '../../domain/repositories/room_repository.dart';

class GetRoomMembersUseCase {
  final RoomRepository _roomRepository;

  GetRoomMembersUseCase(this._roomRepository);

  Future<List<RoomMember>> call(String roomId) async {
    return await _roomRepository.getRoomMembers(roomId);
  }
}
