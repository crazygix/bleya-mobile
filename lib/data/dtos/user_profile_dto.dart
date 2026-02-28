import '../../domain/entities/user_profile.dart';

/// Data Transfer Object for UserProfile - handles JSON parsing.
class UserProfileDto {
  static String _parseId(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['userId'] ?? json['_id'];
    return rawId?.toString() ?? '';
  }

  static UserProfile fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: _parseId(json),
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      createdAt: _parseTimestamp(json['createdAt']),
      lastLogin: _parseTimestamp(json['lastLogin']),
    );
  }

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
}
