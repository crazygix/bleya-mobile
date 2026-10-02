import 'package:bleya/data/repositories/city_repository_impl.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_http_adapter.dart';
import '../../fixtures/api_fixtures.dart';

void main() {
  late FakeHttpAdapter server;
  late CityRepositoryImpl repository;

  /// Answers every request with [body].
  void respondWith(Object body) {
    server = FakeHttpAdapter((_) async => jsonResponse(200, body));
    repository = CityRepositoryImpl(fakeDio(server));
  }

  test('GET /cities/nearby sends the location and lists the cities', () async {
    respondWith([nearbyCityJson(), nearbyCityJson(imageUrl: null)]);

    final cities = await repository.getNearby(
      latitude: 44.8,
      longitude: 20.46,
    );

    final request = server.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/cities/nearby');
    expect(request.queryParameters, {'lat': 44.8, 'lng': 20.46});
    expect(request.uri.query, 'lat=44.8&lng=20.46');
    expect(cities, hasLength(2));
    expect(cities.first.id, FixtureIds.city);
    expect(cities.first.countryName, 'Serbia');
    expect(cities.last.imageUrl, isNull);
  });

  test('POST /cities/:cityId/join returns the city room', () async {
    respondWith(joinCityJson());

    final room = await repository.joinCity(FixtureIds.city);

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/cities/${FixtureIds.city}/join');
    expect(request.data, isNull);
    expect(room.id, FixtureIds.cityRoom);
    expect(room.type, 'public');
    expect(room.cityKey, FixtureIds.city);
  });

  test("a location the server can't read fails with its reason", () async {
    server = FakeHttpAdapter(
      (_) async => apiErrorResponse(
        400,
        'VALIDATION_ERROR',
        "We couldn't read your location. Please try again.",
      ),
    );
    repository = CityRepositoryImpl(fakeDio(server));

    await expectLater(
      repository.getNearby(latitude: 44.8, longitude: 20.46),
      throwsA(
        isA<BadRequestError>().having(
          (e) => e.getUserMessage(),
          'user message',
          "We couldn't read your location. Please try again.",
        ),
      ),
    );
  });
}
