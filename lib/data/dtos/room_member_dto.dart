import '../../domain/entities/room_member.dart';

/// Data Transfer Object for RoomMember - handles JSON parsing
class RoomMemberDto {
  static RoomMember fromJson(Map<String, dynamic> json) {
    return RoomMember(
      id: (json['id'] ?? '').toString(),
      username: json['username'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String? ?? '',
    );
  }
}
