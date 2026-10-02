import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bleya/controllers/username_controller.dart';
import 'package:bleya/domain/entities/user_profile.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/controller_providers.dart';
import 'package:bleya/providers/use_case_providers.dart';
import 'package:bleya/services/passkey_auth_service.dart';
import 'package:bleya/utils/app_errors.dart';
import '../mocks.dart';

void main() {
  late MockCheckUsernameUseCase mockCheckUsername;
  late MockSetUsernameUseCase mockSetUsername;
  late MockUploadProfileImageUseCase mockUploadImage;
  late bool canOfferPasskey;
  late UsernameController controller;

  setUpAll(() {
    registerFallbackValue(MockFile());
  });

  setUp(() {
    mockCheckUsername = MockCheckUsernameUseCase();
    mockSetUsername = MockSetUsernameUseCase();
    mockUploadImage = MockUploadProfileImageUseCase();
    canOfferPasskey = false;
    controller = UsernameController(
      mockCheckUsername,
      mockSetUsername,
      mockUploadImage,
      () async => canOfferPasskey,
    );
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

  group('submitUsername', () {
    test('throws for empty username', () async {
      await expectLater(
        controller.submitUsername(
          '',
          showPasskeyPromptAfterCompletion: false,
        ),
        throwsA(isA<StateError>()),
      );
      expect(controller.state.errorMessage, isNotNull);
    });

    test('throws for invalid format', () async {
      await expectLater(
        controller.submitUsername(
          'a b!',
          showPasskeyPromptAfterCompletion: false,
        ),
        throwsA(isA<StateError>()),
      );
      expect(controller.state.errorMessage, isNotNull);
    });

    test('returns profile on success', () async {
      final profile = UserProfile(id: 'u1', username: 'testuser');
      when(() => mockSetUsername(username: any(named: 'username')))
          .thenAnswer((_) async => profile);

      final result = await controller.submitUsername(
        'testuser',
        showPasskeyPromptAfterCompletion: false,
      );

      expect(result, profile);
      verify(() => mockSetUsername(username: 'testuser')).called(1);
      expect(controller.state.completedProfile, profile);
      expect(
        controller.state.completionRequest?.target,
        UsernameCompletionTarget.home,
      );
    });

    test('uploads image before setting username if selected', () async {
      final mockFile = MockFile();
      final profile = UserProfile(id: 'u1', username: 'testuser');
      controller.setSelectedImage(mockFile);

      when(() => mockUploadImage(any())).thenAnswer((_) async => profile);
      when(() => mockSetUsername(username: any(named: 'username')))
          .thenAnswer((_) async => profile);

      await controller.submitUsername(
        'testuser',
        showPasskeyPromptAfterCompletion: false,
      );

      verifyInOrder([
        () => mockUploadImage(mockFile),
        () => mockSetUsername(username: 'testuser'),
      ]);
    });

    test('sets user-friendly error on AppError', () async {
      when(() => mockSetUsername(username: any(named: 'username')))
          .thenThrow(BadRequestError(userMessage: 'Username taken'));

      await expectLater(
        controller.submitUsername(
          'testuser',
          showPasskeyPromptAfterCompletion: false,
        ),
        throwsA(isA<AppError>()),
      );
      expect(controller.state.errorMessage, 'Username taken');
      expect(controller.state.isLoading, false);
    });

    test('sets generic error on non-AppError', () async {
      when(() => mockSetUsername(username: any(named: 'username')))
          .thenThrow(Exception('something'));

      await expectLater(
        controller.submitUsername(
          'testuser',
          showPasskeyPromptAfterCompletion: false,
        ),
        throwsA(isA<Exception>()),
      );
      expect(controller.state.errorMessage, contains('Something went wrong'));
      expect(controller.state.isLoading, false);
    });

    test('routes to passkey prompt when available after completion', () async {
      canOfferPasskey = true;
      final profile = UserProfile(id: 'u1', username: 'testuser');
      when(() => mockSetUsername(username: any(named: 'username')))
          .thenAnswer((_) async => profile);

      await controller.submitUsername(
        'testuser',
        showPasskeyPromptAfterCompletion: true,
      );

      expect(
        controller.state.completionRequest?.target,
        UsernameCompletionTarget.passkeyPrompt,
      );
    });
  });

  group('clearError', () {
    test('resets error message', () async {
      await expectLater(
        controller.submitUsername(
          '',
          showPasskeyPromptAfterCompletion: false,
        ),
        throwsA(isA<StateError>()),
      );

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

    test('clears the chosen photo', () {
      controller.setSelectedImage(MockFile());

      controller.resetTransientUiState();

      expect(controller.state.selectedImage, isNull);
    });
  });

  group('the profile photo', () {
    test('can be cleared', () {
      controller.setSelectedImage(MockFile());

      controller.setSelectedImage(null);

      expect(controller.state.selectedImage, isNull);
    });

    test('stays chosen through other changes', () {
      final photo = MockFile();
      controller.setSelectedImage(photo);

      controller.setError('Oops');
      controller.clearError();

      expect(controller.state.selectedImage, same(photo));
    });

    test(
        'a photo the server refuses is dropped, so the next try goes ahead '
        'without it', () async {
      final profile = UserProfile(id: 'u1', username: 'testuser');
      controller.setSelectedImage(MockFile());
      when(() => mockUploadImage(any())).thenThrow(
        BadRequestError(
          message: "That image isn't allowed.",
          userMessage: "That image isn't allowed.",
        ),
      );
      when(() => mockSetUsername(username: any(named: 'username')))
          .thenAnswer((_) async => profile);

      await expectLater(
        controller.submitUsername(
          'testuser',
          showPasskeyPromptAfterCompletion: false,
        ),
        throwsA(isA<BadRequestError>()),
      );

      expect(controller.state.selectedImage, isNull);
      expect(controller.state.errorMessage, "That image isn't allowed.");
      expect(controller.state.isLoading, false);
      verifyNever(() => mockSetUsername(username: any(named: 'username')));

      final result = await controller.submitUsername(
        'testuser',
        showPasskeyPromptAfterCompletion: false,
      );

      expect(result, profile);
      // Only the refused upload: the second try had no photo to send.
      verify(() => mockUploadImage(any())).called(1);
    });

    test('a network error keeps the photo for a retry', () async {
      final photo = MockFile();
      controller.setSelectedImage(photo);
      when(() => mockUploadImage(any()))
          .thenThrow(NetworkError(message: 'Network connection error'));

      await expectLater(
        controller.submitUsername(
          'testuser',
          showPasskeyPromptAfterCompletion: false,
        ),
        throwsA(isA<NetworkError>()),
      );

      expect(controller.state.selectedImage, same(photo));
      expect(
        controller.state.errorMessage,
        'Connection issue. Check your internet and try again?',
      );
      verifyNever(() => mockSetUsername(username: any(named: 'username')));
    });

    test('a server error keeps the photo for a retry', () async {
      final photo = MockFile();
      controller.setSelectedImage(photo);
      when(() => mockUploadImage(any())).thenThrow(ServerError());

      await expectLater(
        controller.submitUsername(
          'testuser',
          showPasskeyPromptAfterCompletion: false,
        ),
        throwsA(isA<ServerError>()),
      );

      expect(controller.state.selectedImage, same(photo));
    });
  });

  group('usernameControllerProvider', () {
    test('starts over once the username page is gone', () async {
      final container = ProviderContainer(
        overrides: [
          checkUsernameUseCaseProvider.overrideWithValue(mockCheckUsername),
          setUsernameUseCaseProvider.overrideWithValue(mockSetUsername),
          uploadProfileImageUseCaseProvider.overrideWithValue(mockUploadImage),
          passkeyAuthServiceProvider.overrideWithValue(
            PasskeyAuthService(authenticator: MockPasskeyAuthenticator()),
          ),
        ],
      );
      addTearDown(container.dispose);

      // The username page listens while it shows.
      final page = container.listen(usernameControllerProvider, (_, __) {});
      container
          .read(usernameControllerProvider.notifier)
          .setSelectedImage(MockFile());
      expect(
        container.read(usernameControllerProvider).selectedImage,
        isNotNull,
      );

      // Signing out closes the page; the next sign-up opens a new one.
      page.close();
      await container.pump();

      expect(container.read(usernameControllerProvider).selectedImage, isNull);
    });
  });

  group('consumeCompletion', () {
    test('clears completion state', () async {
      final profile = UserProfile(id: 'u1', username: 'testuser');
      when(() => mockSetUsername(username: any(named: 'username')))
          .thenAnswer((_) async => profile);

      await controller.submitUsername(
        'testuser',
        showPasskeyPromptAfterCompletion: false,
      );

      controller.consumeCompletion();

      expect(controller.state.completedProfile, isNull);
      expect(controller.state.completionRequest, isNull);
    });
  });
}
