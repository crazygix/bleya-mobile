import 'package:bleya/data/dtos/city_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  test('parses an item of GET /cities/nearby', () {
    final city = CityDto.fromJson(nearbyCityJson());

    expect(city.id, FixtureIds.city);
    expect(city.name, 'Belgrade');
    expect(city.country, 'RS');
    expect(city.countryName, 'Serbia');
    expect(city.latitude, 44.80401);
    expect(city.longitude, 20.46513);
    expect(city.imageUrl, 'https://cdn.example.com/cities/belgrade-rs.webp');
  });

  test('reads whole-number coordinates as doubles', () {
    final city = CityDto.fromJson(nearbyCityJson(latitude: 45, longitude: 20));

    expect(city.latitude, 45.0);
    expect(city.longitude, 20.0);
  });

  test('a city without an image has a null imageUrl', () {
    expect(CityDto.fromJson(nearbyCityJson(imageUrl: null)).imageUrl, isNull);
  });
}
