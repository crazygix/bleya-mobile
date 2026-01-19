import '../../domain/entities/room.dart';

/// Data Transfer Object for Room - handles JSON parsing
class RoomDto {
  static Room fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'public',
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      otherUserId: json['otherUserId'] as String?,
    );
  }
}
