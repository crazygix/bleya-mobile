import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bleya/controllers/auth_controller.dart';
import 'package:bleya/domain/entities/auth_result.dart';
import '../mocks.dart';

void main() {
  late MockRequestCodeUseCase mockRequestCode;
  late MockResendCodeUseCase mockResendCode;
  late MockVerifyCodeUseCase mockVerifyCode;
  late AuthController controller;

  setUp(() {
    mockRequestCode = MockRequestCodeUseCase();
    mockResendCode = MockResendCodeUseCase();
    mockVerifyCode = MockVerifyCodeUseCase();
    controller =
        AuthController(mockRequestCode, mockResendCode, mockVerifyCode);
  });

  group('requestCode', () {
    test('sets error when phone is empty', () async {
      final result = await controller.requestCode('');

      expect(result, isNull);
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.isLoading, false);
      verifyNever(() => mockRequestCode(phone: any(named: 'phone')));
    });

    test('returns result on success', () async {
      const expected = CodeRequestResult(codeSentAt: 123);
      when(() => mockRequestCode(phone: any(named: 'phone')))
          .thenAnswer((_) async => expected);

      final result = await controller.requestCode('+123');

      expect(result, expected);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNull);
    });

    test('sets error and rethrows on failure', () async {
      when(() => mockRequestCode(phone: any(named: 'phone')))
          .thenThrow(Exception('network'));

      await expectLater(
        controller.requestCode('+123'),
        throwsA(isA<Exception>()),
      );
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNotNull);
    });
  });

  group('resendCode', () {
    test('returns result on success', () async {
      const expected = CodeRequestResult(codeSentAt: 123);
      when(() => mockResendCode(phone: any(named: 'phone')))
          .thenAnswer((_) async => expected);

      final result = await controller.resendCode('+123');

      expect(result, expected);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNull);
    });

    test('sets error and rethrows on failure', () async {
      when(() => mockResendCode(phone: any(named: 'phone')))
          .thenThrow(Exception('error'));

      await expectLater(
        controller.resendCode('+123'),
        throwsA(isA<Exception>()),
      );
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNotNull);
    });
  });

  group('verifyCode', () {
    test('sets error when code is less than 6 chars', () async {
      final result =
          await controller.verifyCode(phone: '+123', code: '123');

      expect(result, isNull);
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.isLoading, false);
      verifyNever(() => mockVerifyCode(
            phone: any(named: 'phone'),
            code: any(named: 'code'),
          ));
    });

    test('returns result on success', () async {
      const expected =
          VerifyCodeResult(token: 'tok', requiresUsername: false);
      when(() => mockVerifyCode(
            phone: any(named: 'phone'),
            code: any(named: 'code'),
          )).thenAnswer((_) async => expected);

      final result =
          await controller.verifyCode(phone: '+123', code: '123456');

      expect(result, expected);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNull);
    });

    test('sets error and rethrows on failure', () async {
      when(() => mockVerifyCode(
            phone: any(named: 'phone'),
            code: any(named: 'code'),
          )).thenThrow(Exception('invalid'));

      await expectLater(
        controller.verifyCode(phone: '+123', code: '123456'),
        throwsA(isA<Exception>()),
      );
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNotNull);
    });
  });

  group('clearError', () {
    test('resets error message', () async {
      await controller.requestCode('');
      expect(controller.state.errorMessage, isNotNull);

      controller.clearError();
      expect(controller.state.errorMessage, isNull);
    });
  });
}
