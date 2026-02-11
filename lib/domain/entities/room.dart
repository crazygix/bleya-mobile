/// Domain entity for Room - pure business object, no JSON parsing
class RoomLocation {
  final double latitude;
  final double longitude;

  const RoomLocation({
    required this.latitude,
    required this.longitude,
  });
}

class Room {
  final String id;
  final String name;
  final String type; // 'public' or 'private'
  final List<String> participants; // User IDs for private chats
  final String? otherUserId; // For private chats, the other user's ID
  final String? lastMessageText;
  final DateTime? lastMessageTime;
  final String? lastMessageUserId;
  final String? lastMessageUsername;
  final int unreadCount;
  final bool hasUnreadCount;
  final String? imageUrl;
  final String? cityKey;
  final RoomLocation? location;
  final double? distanceKm;
  final bool isJoined;

  Room({
    required this.id,
    required this.name,
    this.type = 'public',
    this.participants = const [],
    this.otherUserId,
    this.lastMessageText,
    this.lastMessageTime,
    this.lastMessageUserId,
    this.lastMessageUsername,
    this.unreadCount = 0,
    this.hasUnreadCount = false,
    this.imageUrl,
    this.cityKey,
    this.location,
    this.distanceKm,
    this.isJoined = false,
  });

  bool get isPrivate => type == 'private';

  @override
  String toString() => '$name (id: $id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Room && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
