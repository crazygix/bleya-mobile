import 'package:bleya/domain/entities/auth_result.dart';
import 'package:bleya/domain/entities/user_profile.dart';
import 'package:bleya/use_cases/auth/check_username_use_case.dart';
import 'package:bleya/use_cases/auth/link_auth_provider_use_case.dart';
import 'package:bleya/use_cases/auth/register_passkey_use_case.dart';
import 'package:bleya/use_cases/auth/set_username_use_case.dart';
import 'package:bleya/use_cases/auth/sign_in_with_apple_use_case.dart';
import 'package:bleya/use_cases/auth/sign_in_with_google_use_case.dart';
import 'package:bleya/use_cases/auth/sign_in_with_passkey_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../mocks.dart';

void main() {
  late MockAuthRepository mockRepo;

  const session = AuthSessionResult(
    token: 'token123',
    requiresUsername: true,
    hasPasskey: false,
  );
  const securityStatus = AuthSecurityStatus(
    hasPasskey: true,
    linkedProviders: [],
  );

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  group('provider sign-in use cases', () {
    test('SignInWithGoogleUseCase delegates to repository', () async {
      final useCase = SignInWithGoogleUseCase(mockRepo);
      when(() => mockRepo.signInWithGoogle())
          .thenAnswer((_) async => session);

      final result = await useCase();

      expect(result, session);
      verify(() => mockRepo.signInWithGoogle()).called(1);
    });

    test('SignInWithAppleUseCase delegates to repository', () async {
      final useCase = SignInWithAppleUseCase(mockRepo);
      when(() => mockRepo.signInWithApple())
          .thenAnswer((_) async => session);

      final result = await useCase();

      expect(result, session);
      verify(() => mockRepo.signInWithApple()).called(1);
    });

    test('SignInWithPasskeyUseCase delegates to repository', () async {
      final useCase = SignInWithPasskeyUseCase(mockRepo);
      when(() => mockRepo.signInWithPasskey())
          .thenAnswer((_) async => session);

      final result = await useCase();

      expect(result, session);
      verify(() => mockRepo.signInWithPasskey()).called(1);
    });
  });

  group('security use cases', () {
    test('LinkAuthProviderUseCase delegates to repository', () async {
      final useCase = LinkAuthProviderUseCase(mockRepo);
      when(() => mockRepo.linkProvider(AuthProvider.google))
          .thenAnswer((_) async => securityStatus);

      final result = await useCase(provider: AuthProvider.google);

      expect(result, securityStatus);
      verify(() => mockRepo.linkProvider(AuthProvider.google)).called(1);
    });

    test('RegisterPasskeyUseCase delegates to repository', () async {
      final useCase = RegisterPasskeyUseCase(mockRepo);
      when(() => mockRepo.registerPasskey())
          .thenAnswer((_) async => securityStatus);

      final result = await useCase();

      expect(result, securityStatus);
      verify(() => mockRepo.registerPasskey()).called(1);
    });
  });

  group('username use cases', () {
    test('CheckUsernameUseCase returns repository result', () async {
      final useCase = CheckUsernameUseCase(mockRepo);
      when(() => mockRepo.checkUsername(username: any(named: 'username')))
          .thenAnswer((_) async => true);

      final result = await useCase(username: 'newuser');

      expect(result, true);
      verify(() => mockRepo.checkUsername(username: 'newuser')).called(1);
    });

    test('SetUsernameUseCase delegates to repository', () async {
      final useCase = SetUsernameUseCase(mockRepo);
      final expected = UserProfile(id: '1', username: 'testuser');
      when(() => mockRepo.setUsername(username: any(named: 'username')))
          .thenAnswer((_) async => expected);

      final result = await useCase(username: 'testuser');

      expect(result, expected);
      verify(() => mockRepo.setUsername(username: 'testuser')).called(1);
    });
  });
}
