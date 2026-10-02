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
    return null;
  }
}
```

## Fixtures: the backend's shapes in the tests

`test/fixtures/api_fixtures.dart` holds one fixture per backend response the app reads, plus the socket events and
push data it parses. Each fixture copies a backend serializer and names it in its doc comment (for example
`formatMessage` in `utils/message.ts`, or `getJoinedRoomsForUser` in `services/roomService.ts`).

- **Copy, don't tidy.** Keep nulls, empty strings and missing keys exactly as the backend sends them: `|| null`
  becomes `null`, `|| ''` becomes `''`, and an `undefined` value is left out, as JSON drops it.
- **Change both together.** When a backend response changes, change its fixture, and the DTO and repository tests
  that use it, in the same change. A fixture that no longer matches its serializer hides exactly the bugs these
  tests exist to catch.
- **One repository test per endpoint.** Each HTTP call a repository makes has a test in
  `test/data/repositories/<name>_repository_impl_test.dart`. It checks the request (method, path, query, body) and
  the result parsed from the fixture, against `FakeHttpAdapter` (`test/fakes/fake_http_adapter.dart`). Each
  repository also has at least one test that the backend's `{error: {code, message}}` response reaches the caller as
  the right `AppError`, with the backend's message.
- **One DTO test file per DTO** in `test/data/dtos/`, parsing its fixtures, including the fallbacks the DTO applies.
