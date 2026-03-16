## API Contract Rules (Mobile DTOs)

These rules describe how the mobile app expects data from the backend at the DTO boundary.

```dart
/// Data Transfer Object for Message - handles JSON parsing
/// Always expects timestamps (milliseconds since epoch), never ISO strings
class MessageDto {
  static Message fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      json['createdAt'] as int,
    );

    return Message(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String? ?? '',
      text: json['text'] as String,
      createdAt: createdAt,
      parentMessageId: json['parentMessageId'] as String?,
      replyCount: json['replyCount'] as int? ?? 0,
    );
  }
}
```

```dart
/// Data Transfer Object for UserProfile - handles JSON parsing
/// Always expects timestamps (milliseconds since epoch), never ISO strings
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
```
