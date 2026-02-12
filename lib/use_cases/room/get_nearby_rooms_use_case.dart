import '../../domain/entities/room.dart';
import '../../domain/repositories/room_repository.dart';

class GetNearbyRoomsUseCase {
  final RoomRepository _roomRepository;

  GetNearbyRoomsUseCase(this._roomRepository);

  Future<List<Room>> call({
    required double latitude,
    required double longitude,
    double radiusKm = 30,
    int limit = 20,
    String? searchQuery,
  }) async {
    return await _roomRepository.getNearbyRooms(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      limit: limit,
      searchQuery: searchQuery,
    );
  }
}
