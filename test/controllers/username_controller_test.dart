import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bleya/controllers/username_controller.dart';
import 'package:bleya/domain/entities/user_profile.dart';
import 'package:bleya/utils/app_errors.dart';
import '../mocks.dart';

void main() {
  late MockCheckUsernameUseCase mockCheckUsername;
  late MockSetUsernameUseCase mockSetUsername;
  late MockUploadProfileImageUseCase mockUploadImage;
  late UsernameController controller;

  setUpAll(() {
    registerFallbackValue(MockFile());
  });

  setUp(() {
    mockCheckUsername = MockCheckUsernameUseCase();
    mockSetUsername = MockSetUsernameUseCase();
    mockUploadImage = MockUploadProfileImageUseCase();
    controller = UsernameController(
        mockCheckUsername, mockSetUsername, mockUploadImage);
  });

  group('validateUsername', () {
    test('sets isValid false for short usernames', () {
      controller.validateUsername('ab');

      expect(controller.state.isValid, false);
      expect(controller.state.isChecking, false);
    });

    test('sets isValid false for invalid characters', () {
      controller.validateUsername('user name!');

      expect(controller.state.isValid, false);
      expect(controller.state.isChecking, false);
    });

    test('checks availability after debounce for valid input', () {
      fakeAsync((async) {
        when(() => mockCheckUsername(username: any(named: 'username')))
            .thenAnswer((_) async => true);

        controller.validateUsername('validuser');
        expect(controller.state.isChecking, true);

        async.elapse(const Duration(milliseconds: 500));

        expect(controller.state.isValid, true);
        expect(controller.state.isChecking, false);
        expect(controller.state.hasCheckedAvailability, true);
      });
    });

    test('sets isValid false when username is taken', () {
      fakeAsync((async) {
        when(() => mockCheckUsername(username: any(named: 'username')))
            .thenAnswer((_) async => false);

        controller.validateUsername('takenuser');
        async.elapse(const Duration(milliseconds: 500));

        expect(controller.state.isValid, false);
        expect(controller.state.hasCheckedAvailability, true);
      });
    });

    test('cancels previous debounce on rapid input', () {
      fakeAsync((async) {
        when(() => mockCheckUsername(username: any(named: 'username')))
            .thenAnswer((_) async => true);

        controller.validateUsername('first');
        async.elapse(const Duration(milliseconds: 200));
        controller.validateUsername('second');
        async.elapse(const Duration(milliseconds: 500));

        verify(() => mockCheckUsername(username: 'second')).called(1);
        verifyNever(() => mockCheckUsername(username: 'first'));
      });
    });
  });

  group('setUsername', () {
    test('throws for empty username', () async {
      await expectLater(
        controller.setUsername(''),
        throwsA(isA<StateError>()),
      );
      expect(controller.state.errorMessage, isNotNull);
    });

    test('throws for invalid format', () async {
      await expectLater(
        controller.setUsername('a b!'),
        throwsA(isA<StateError>()),
      );
      expect(controller.state.errorMessage, isNotNull);
    });

    test('returns profile on success', () async {
      final profile = UserProfile(id: 'u1', username: 'testuser');
      when(() => mockSetUsername(username: any(named: 'username')))
          .thenAnswer((_) async => profile);

      final result = await controller.setUsername('testuser');

      expect(result, profile);
      verify(() => mockSetUsername(username: 'testuser')).called(1);
    });

    test('uploads image before setting username if selected', () async {
      final mockFile = MockFile();
      final profile = UserProfile(id: 'u1', username: 'testuser');
      controller.setSelectedImage(mockFile);

      when(() => mockUploadImage(any()))
          .thenAnswer((_) async => profile);
      when(() => mockSetUsername(username: any(named: 'username')))
          .thenAnswer((_) async => profile);

      await controller.setUsername('testuser');

      verifyInOrder([
        () => mockUploadImage(mockFile),
        () => mockSetUsername(username: 'testuser'),
      ]);
    });

    test('sets user-friendly error on AppError', () async {
      when(() => mockSetUsername(username: any(named: 'username')))
          .thenThrow(BadRequestError(userMessage: 'Username taken'));

      await expectLater(
        controller.setUsername('testuser'),
        throwsA(isA<AppError>()),
      );
      expect(controller.state.errorMessage, 'Username taken');
      expect(controller.state.isLoading, false);
    });

    test('sets generic error on non-AppError', () async {
      when(() => mockSetUsername(username: any(named: 'username')))
          .thenThrow(Exception('something'));

      await expectLater(
        controller.setUsername('testuser'),
        throwsA(isA<Exception>()),
      );
      expect(controller.state.errorMessage, contains('Something went wrong'));
      expect(controller.state.isLoading, false);
    });
  });

  group('clearError', () {
    test('resets error message', () async {
      await expectLater(
          controller.setUsername(''), throwsA(isA<StateError>()));

      controller.clearError();
      expect(controller.state.errorMessage, isNull);
    });
  });

  group('resetTransientUiState', () {
    test('resets all transient state', () {
      controller.resetTransientUiState();

      expect(controller.state.isValid, false);
      expect(controller.state.isChecking, false);
      expect(controller.state.hasCheckedAvailability, false);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.isLoading, false);
    });
  });
}
