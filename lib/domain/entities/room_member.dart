/// Domain entity for RoomMember - pure business object, no JSON parsing
class RoomMember {
  final String id;
  final String username;
  final String phoneNumber;
  final String profileImageUrl;

  RoomMember({
    required this.id,
    required this.username,
    required this.phoneNumber,
    required this.profileImageUrl,
  });
}
