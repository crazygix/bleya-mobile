import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bleya/use_cases/auth/request_code_use_case.dart';
import 'package:bleya/use_cases/auth/resend_code_use_case.dart';
import 'package:bleya/use_cases/auth/verify_code_use_case.dart';
import 'package:bleya/use_cases/auth/check_username_use_case.dart';
import 'package:bleya/use_cases/auth/set_username_use_case.dart';
import 'package:bleya/domain/entities/auth_result.dart';
import 'package:bleya/domain/entities/user_profile.dart';
import '../mocks.dart';

void main() {
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  group('RequestCodeUseCase', () {
    late RequestCodeUseCase useCase;

    setUp(() {
      useCase = RequestCodeUseCase(mockRepo);
    });

    test('delegates to repository.requestCode', () async {
      const expected = CodeRequestResult(codeSentAt: 1234567890);
      when(() => mockRepo.requestCode(phone: any(named: 'phone')))
          .thenAnswer((_) async => expected);

      final result = await useCase(phone: '+1234567890');

      expect(result, expected);
      verify(() => mockRepo.requestCode(phone: '+1234567890')).called(1);
    });

    test('propagates repository exceptions', () async {
      when(() => mockRepo.requestCode(phone: any(named: 'phone')))
          .thenThrow(Exception('network error'));

      expect(() => useCase(phone: '+1234567890'), throwsException);
    });
  });

  group('ResendCodeUseCase', () {
    late ResendCodeUseCase useCase;

    setUp(() {
      useCase = ResendCodeUseCase(mockRepo);
    });

    test('delegates to repository.resendCode', () async {
      const expected = CodeRequestResult(codeSentAt: 1234567890);
      when(() => mockRepo.resendCode(phone: any(named: 'phone')))
          .thenAnswer((_) async => expected);

      final result = await useCase(phone: '+1234567890');

      expect(result, expected);
      verify(() => mockRepo.resendCode(phone: '+1234567890')).called(1);
    });
  });

  group('VerifyCodeUseCase', () {
    late VerifyCodeUseCase useCase;

    setUp(() {
      useCase = VerifyCodeUseCase(mockRepo);
    });

    test('delegates to repository.verifyCode', () async {
      const expected =
          VerifyCodeResult(token: 'token123', requiresUsername: true);
      when(() => mockRepo.verifyCode(
            phone: any(named: 'phone'),
            code: any(named: 'code'),
          )).thenAnswer((_) async => expected);

      final result = await useCase(phone: '+123', code: '123456');

      expect(result, expected);
      verify(() => mockRepo.verifyCode(phone: '+123', code: '123456'))
          .called(1);
    });
  });

  group('CheckUsernameUseCase', () {
    late CheckUsernameUseCase useCase;

    setUp(() {
      useCase = CheckUsernameUseCase(mockRepo);
    });

    test('returns true when username is available', () async {
      when(() => mockRepo.checkUsername(username: any(named: 'username')))
          .thenAnswer((_) async => true);

      final result = await useCase(username: 'newuser');

      expect(result, true);
      verify(() => mockRepo.checkUsername(username: 'newuser')).called(1);
    });

    test('returns false when username is taken', () async {
      when(() => mockRepo.checkUsername(username: any(named: 'username')))
          .thenAnswer((_) async => false);

      expect(await useCase(username: 'taken'), false);
    });
  });

  group('SetUsernameUseCase', () {
    late SetUsernameUseCase useCase;

    setUp(() {
      useCase = SetUsernameUseCase(mockRepo);
    });

    test('delegates to repository.setUsername', () async {
      final expected = UserProfile(id: '1', username: 'testuser');
      when(() => mockRepo.setUsername(username: any(named: 'username')))
          .thenAnswer((_) async => expected);

      final result = await useCase(username: 'testuser');

      expect(result, expected);
      verify(() => mockRepo.setUsername(username: 'testuser')).called(1);
    });
  });
}
