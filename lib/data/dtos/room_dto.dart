import '../../domain/entities/room.dart';

/// Data Transfer Object for Room - handles JSON parsing
class RoomDto {
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

  static Room fromJson(Map<String, dynamic> json) {
    final lastMessageTime = _parseTimestamp(json['lastMessageTime']);

    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'public',
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      otherUserId: json['otherUserId'] as String?,
      lastMessageText: json['lastMessageText'] as String?,
      lastMessageTime: lastMessageTime,
      lastMessageUserId: json['lastMessageUserId'] as String?,
      lastMessageUsername: json['lastMessageUsername'] as String?,
    );
  }
}
