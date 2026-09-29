import '../../domain/entities/room_member.dart';
import '../../domain/repositories/room_repository.dart';

class GetRoomMembersUseCase {
  final RoomRepository _roomRepository;

  GetRoomMembersUseCase(this._roomRepository);

  /// One page of members, sorted by username.
  Future<List<RoomMember>> call(
    String roomId, {
    required int limit,
    int offset = 0,
  }) async {
    return await _roomRepository.getRoomMembers(
      roomId,
      limit: limit,
      offset: offset,
    );
  }
}
