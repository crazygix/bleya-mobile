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

  static int _parseUnreadCount(dynamic value) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }
    if (value is double) {
      final rounded = value.round();
      return rounded < 0 ? 0 : rounded;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed < 0 ? 0 : parsed;
      }
    }
    return 0;
  }

  static double? _parseDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static RoomLocation? _parseLocation(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final latitude = _parseDouble(value['latitude']);
    final longitude = _parseDouble(value['longitude']);

    if (latitude == null || longitude == null) {
      return null;
    }

    return RoomLocation(
      latitude: latitude,
      longitude: longitude,
    );
  }

  static bool _parseIsJoined(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  static Room fromJson(Map<String, dynamic> json) {
    final lastMessageTime = _parseTimestamp(json['lastMessageTime']);
    final hasUnreadCount = json.containsKey('unreadCount');
    final unreadCount =
        hasUnreadCount ? _parseUnreadCount(json['unreadCount']) : 0;

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
      unreadCount: unreadCount,
      hasUnreadCount: hasUnreadCount,
      imageUrl: json['imageUrl'] as String?,
      cityKey: json['cityKey'] as String?,
      location: _parseLocation(json['location']),
      distanceKm: _parseDouble(json['distanceKm']),
      isJoined: _parseIsJoined(json['isJoined']),
    );
  }
}
