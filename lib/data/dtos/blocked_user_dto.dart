import '../../domain/entities/blocked_user.dart';

class BlockedUserDto {
  static DateTime? _parseTimestamp(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return DateTime.fromMillisecondsSinceEpoch(parsed);
      }
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
