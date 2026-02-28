/// Domain entity for RoomMember - pure business object, no JSON parsing
class RoomMember {
  final String id;
  final String username;
  final String bio;
  final String profileImageUrl;

  RoomMember({
    required this.id,
    required this.username,
    required this.bio,
    required this.profileImageUrl,
  });
}
