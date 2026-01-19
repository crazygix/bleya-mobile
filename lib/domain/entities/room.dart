/// Domain entity for Room - pure business object, no JSON parsing
class Room {
  final String id;
  final String name;
  final String type; // 'public' or 'private'
  final List<String> participants; // User IDs for private chats
  final String? otherUserId; // For private chats, the other user's ID

  Room({
    required this.id,
    required this.name,
    this.type = 'public',
    this.participants = const [],
    this.otherUserId,
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
