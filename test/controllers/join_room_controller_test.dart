import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bleya/controllers/join_room_controller.dart';
import 'package:bleya/domain/entities/city.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/utils/app_errors.dart';
import '../mocks.dart';

Position _testPosition() => Position(
      latitude: 45.8,
      longitude: 15.97,
      timestamp: DateTime(2025, 1, 1),
      accuracy: 10.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

void main() {
  late MockGetNearbyCitiesUseCase mockGetNearbyCities;
  late MockJoinCityUseCase mockJoinCity;
  late MockGetCurrentLocationUseCase mockGetLocation;
  late JoinRoomController controller;

  setUp(() {
    mockGetNearbyCities = MockGetNearbyCitiesUseCase();
    mockJoinCity = MockJoinCityUseCase();
    mockGetLocation = MockGetCurrentLocationUseCase();
    controller = JoinRoomController(
        mockGetNearbyCities, mockJoinCity, mockGetLocation);
    controller.addListener((_) {});
  });

  final testCities = [
    City(
      id: 'c1',
      name: 'Zagreb',
      country: 'HR',
      countryName: 'Croatia',
      latitude: 45.8,
      longitude: 15.97,
    ),
  ];

  group('shareLocationAndSearch', () {
    test('gets location and fetches nearby cities on success', () async {
      when(() => mockGetLocation())
          .thenAnswer((_) async => _testPosition());
      when(() => mockGetNearbyCities(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => testCities);

      await controller.shareLocationAndSearch();

      expect(controller.state.step, JoinRoomStep.results);
      expect(controller.state.nearbyCities, testCities);
      expect(controller.state.isSearchingNearby, false);
      expect(controller.state.latitude, 45.8);
      expect(controller.state.longitude, 15.97);
    });

    test('sets error on location service disabled', () async {
      when(() => mockGetLocation())
          .thenThrow(const AppLocationServiceDisabledException());

      await controller.shareLocationAndSearch();

      expect(controller.state.searchError, isNotNull);
      expect(controller.state.isSearchingNearby, false);
    });

    test('sets error on permission denied', () async {
      when(() => mockGetLocation())
          .thenThrow(const AppPermissionDeniedException());

      await controller.shareLocationAndSearch();

      expect(controller.state.searchError, isNotNull);
      expect(controller.state.isSearchingNearby, false);
    });

    test('handles permanent permission denial', () async {
      when(() => mockGetLocation())
          .thenThrow(const AppPermissionDeniedForeverException());

      await controller.shareLocationAndSearch();

      expect(controller.state.isLocationPermDeniedForever, true);
      expect(controller.state.searchError, isNotNull);
      expect(controller.state.step, JoinRoomStep.results);
    });

    test('handles unknown errors gracefully', () async {
      when(() => mockGetLocation()).thenThrow(Exception('unexpected'));

      await controller.shareLocationAndSearch();

      expect(controller.state.searchError, isNotNull);
      expect(controller.state.isSearchingNearby, false);
    });
  });

  group('fetchNearbyCities', () {
    test('returns error if location not available', () async {
      await controller.fetchNearbyCities();

      expect(controller.state.searchError, isNotNull);
    });

    test('fetches cities when location is available', () async {
      when(() => mockGetLocation())
          .thenAnswer((_) async => _testPosition());
      when(() => mockGetNearbyCities(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => testCities);

      await controller.shareLocationAndSearch();
      expect(controller.state.nearbyCities, testCities);

      when(() => mockGetNearbyCities(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => []);

      await controller.fetchNearbyCities();

      expect(controller.state.nearbyCities, isEmpty);
      expect(controller.state.isSearchingNearby, false);
    });

    test('sets error on AppError', () async {
      when(() => mockGetLocation())
          .thenAnswer((_) async => _testPosition());
      when(() => mockGetNearbyCities(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => testCities);
      await controller.shareLocationAndSearch();

      when(() => mockGetNearbyCities(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenThrow(BadRequestError(userMessage: 'Bad input'));

      await controller.fetchNearbyCities();

      expect(controller.state.searchError, 'Bad input');
      expect(controller.state.nearbyCities, isEmpty);
    });
  });

  group('joinCity', () {
    test('joins city and resets state', () async {
      final city = testCities.first;
      final room = Room(id: 'r1', name: 'Zagreb Chat');
      when(() => mockJoinCity(any())).thenAnswer((_) async => room);

      await controller.joinCity(city);

      expect(controller.state.isJoining, false);
      expect(controller.state.joiningCityId, isNull);
      verify(() => mockJoinCity('c1')).called(1);
    });

    test('resets joining state even on error', () async {
      final city = testCities.first;
      when(() => mockJoinCity(any())).thenThrow(Exception('error'));

      await expectLater(
        controller.joinCity(city),
        throwsA(isA<Exception>()),
      );

      expect(controller.state.isJoining, false);
      expect(controller.state.joiningCityId, isNull);
    });
  });

  group('onSearchQueryChanged', () {
    test('updates search query', () {
      controller.onSearchQueryChanged('test');
      expect(controller.state.searchQuery, 'test');
    });

    test('trims whitespace', () {
      controller.onSearchQueryChanged('  test  ');
      expect(controller.state.searchQuery, 'test');
    });

    test('ignores duplicate values', () {
      controller.onSearchQueryChanged('test');
      controller.onSearchQueryChanged('  test  ');
      expect(controller.state.searchQuery, 'test');
    });
  });

  group('clearSearchQuery', () {
    test('resets search query', () {
      controller.onSearchQueryChanged('test');
      controller.clearSearchQuery();
      expect(controller.state.searchQuery, isEmpty);
    });

    test('no-op when already empty', () {
      controller.clearSearchQuery();
      expect(controller.state.searchQuery, isEmpty);
    });
  });
}
