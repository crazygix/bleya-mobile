import '../../domain/entities/blocked_user.dart';

class BlockedUserDto {
  static DateTime? _parseTimestamp(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  static BlockedUser fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String?,
      blockedAt: _parseTimestamp(json['blockedAt']),
    );
  }
}
