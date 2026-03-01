import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bleya/use_cases/location/get_current_location_use_case.dart';
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
  late MockLocationRepository mockRepo;
  late GetCurrentLocationUseCase useCase;

  setUp(() {
    mockRepo = MockLocationRepository();
    useCase = GetCurrentLocationUseCase(mockRepo);
  });

  group('call', () {
    test('returns position when services enabled and permission granted',
        () async {
      when(() => mockRepo.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockRepo.checkPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);
      when(() => mockRepo.getCurrentPosition(
              timeLimit: any(named: 'timeLimit')))
          .thenAnswer((_) async => _testPosition());

      final result = await useCase();

      expect(result.latitude, 45.8);
      expect(result.longitude, 15.97);
      verify(() =>
              mockRepo.getCurrentPosition(timeLimit: any(named: 'timeLimit')))
          .called(1);
    });

    test('throws when location services disabled', () async {
      when(() => mockRepo.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      await expectLater(
        useCase(),
        throwsA(isA<AppLocationServiceDisabledException>()),
      );
      verifyNever(() => mockRepo.checkPermission());
    });

    test('requests permission when initially denied, succeeds on grant',
        () async {
      when(() => mockRepo.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockRepo.checkPermission())
          .thenAnswer((_) async => LocationPermission.denied);
      when(() => mockRepo.requestPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);
      when(() => mockRepo.getCurrentPosition(
              timeLimit: any(named: 'timeLimit')))
          .thenAnswer((_) async => _testPosition());

      final result = await useCase();

      expect(result.latitude, 45.8);
      verify(() => mockRepo.requestPermission()).called(1);
    });

    test('throws when permission denied after request', () async {
      when(() => mockRepo.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockRepo.checkPermission())
          .thenAnswer((_) async => LocationPermission.denied);
      when(() => mockRepo.requestPermission())
          .thenAnswer((_) async => LocationPermission.denied);

      await expectLater(
        useCase(),
        throwsA(isA<AppPermissionDeniedException>()),
      );
    });

    test('throws when permission permanently denied', () async {
      when(() => mockRepo.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockRepo.checkPermission())
          .thenAnswer((_) async => LocationPermission.deniedForever);

      await expectLater(
        useCase(),
        throwsA(isA<AppPermissionDeniedForeverException>()),
      );
    });
  });

  group('openAppSettings', () {
    test('delegates to repository', () async {
      when(() => mockRepo.openAppSettings()).thenAnswer((_) async => true);

      await useCase.openAppSettings();

      verify(() => mockRepo.openAppSettings()).called(1);
    });
  });
}
