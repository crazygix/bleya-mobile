import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bleya/use_cases/city/get_nearby_cities_use_case.dart';
import 'package:bleya/use_cases/city/join_city_use_case.dart';
import 'package:bleya/domain/entities/city.dart';
import 'package:bleya/domain/entities/room.dart';
import '../mocks.dart';

void main() {
  late MockCityRepository mockRepo;

  setUp(() {
    mockRepo = MockCityRepository();
  });

  group('GetNearbyCitiesUseCase', () {
    test('delegates to repository.getNearby', () async {
      final cities = [
        City(
          id: 'c1',
          name: 'Zagreb',
          country: 'HR',
          countryName: 'Croatia',
          latitude: 45.8,
          longitude: 15.97,
        ),
      ];
      when(() => mockRepo.getNearby(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => cities);
      final useCase = GetNearbyCitiesUseCase(mockRepo);

      final result = await useCase(latitude: 45.8, longitude: 15.97);

      expect(result, cities);
      verify(() => mockRepo.getNearby(latitude: 45.8, longitude: 15.97))
          .called(1);
    });
  });

  group('JoinCityUseCase', () {
    test('delegates to repository.joinCity', () async {
      final room = Room(id: 'r1', name: 'Zagreb Chat');
      when(() => mockRepo.joinCity(any())).thenAnswer((_) async => room);
      final useCase = JoinCityUseCase(mockRepo);

      final result = await useCase('c1');

      expect(result, room);
      verify(() => mockRepo.joinCity('c1')).called(1);
    });
  });
}
