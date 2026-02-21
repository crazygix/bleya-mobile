import '../entities/room.dart';
import '../entities/room_member.dart';
import '../entities/direct_chat_status.dart';

/// Domain repository interface for room operations
/// Use cases depend on this interface, not concrete implementations
abstract class RoomRepository {
  Future<List<Room>> getAvailableRooms();

  Future<List<Room>> getJoinedRooms();
  Future<Room> joinRoom(String roomId);
  Future<List<RoomMember>> getRoomMembers(String roomId);
  Future<void> leaveRoom(String roomId);
  Future<Room> createDirectMessage(String otherUserId);
  Future<DirectChatStatus> getDirectChatStatus(String otherUserId);
  Future<DirectChatActionResult> deleteDirectChat(String otherUserId);
  Future<DirectChatActionResult> blockDirectChat(String otherUserId);
  Future<Room> getRoom(String roomId);
}
