class Room {
  final String id;
  final String name;

  Room({required this.id, required this.name});

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  @override
  String toString() => '$name (id: $id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Room && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

