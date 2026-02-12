import '../entities/room.dart';
import '../entities/room_member.dart';

/// Domain repository interface for room operations
/// Use cases depend on this interface, not concrete implementations
abstract class RoomRepository {
  Future<List<Room>> getAvailableRooms();
  Future<List<Room>> getNearbyRooms({
    required double latitude,
    required double longitude,
    double radiusKm,
    int limit,
    String? searchQuery,
  });
  Future<List<Room>> getJoinedRooms();
  Future<Room> joinRoom(String roomId);
  Future<List<RoomMember>> getRoomMembers(String roomId);
  Future<void> leaveRoom(String roomId);
  Future<Room> createDirectMessage(String otherUserId);
  Future<Room> getRoom(String roomId);
}
