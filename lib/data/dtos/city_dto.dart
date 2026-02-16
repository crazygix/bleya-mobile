import '../../domain/entities/city.dart';

class CityDto {
  static City fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      countryName: json['countryName'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String?,
    );
  }

  static Map<String, dynamic> toJson(City city) {
    return {
      'id': city.id,
      'name': city.name,
      'country': city.country,
      'countryName': city.countryName,
      'latitude': city.latitude,
      'longitude': city.longitude,
      'imageUrl': city.imageUrl,
    };
  }
}
