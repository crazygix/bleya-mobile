class City {
  final String id;
  final String name;
  final String country;
  final String countryName;
  final double latitude;
  final double longitude;
  final String? imageUrl;

  City({
    required this.id,
    required this.name,
    required this.country,
    required this.countryName,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is City && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'City(id: $id, name: $name, country: $countryName)';
}
