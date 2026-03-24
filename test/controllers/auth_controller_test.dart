import 'package:bleya/controllers/auth_controller.dart';
import 'package:bleya/domain/entities/auth_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../mocks.dart';

void main() {
  late MockSignInWithGoogleUseCase mockSignInWithGoogle;
  late MockSignInWithAppleUseCase mockSignInWithApple;
  late MockSignInWithPasskeyUseCase mockSignInWithPasskey;
  late MockRegisterPasskeyUseCase mockRegisterPasskey;
  late List<String> storedTokens;
  late bool canOfferPasskey;
  late AuthController controller;

  const session = AuthSessionResult(
    token: 'token-123',
    requiresUsername: false,
    hasPasskey: false,
  );
  const securityStatus = AuthSecurityStatus(
    hasPasskey: true,
  );

  setUp(() {
    mockSignInWithGoogle = MockSignInWithGoogleUseCase();
    mockSignInWithApple = MockSignInWithAppleUseCase();
    mockSignInWithPasskey = MockSignInWithPasskeyUseCase();
    mockRegisterPasskey = MockRegisterPasskeyUseCase();
    storedTokens = [];
    canOfferPasskey = false;

    controller = AuthController(
      mockSignInWithGoogle,
      mockSignInWithApple,
      mockSignInWithPasskey,
      mockRegisterPasskey,
      storedTokens.add,
      () async => canOfferPasskey,
    );
  });

  group('signInWithGoogle', () {
    test('returns session result on success', () async {
      when(() => mockSignInWithGoogle()).thenAnswer((_) async => session);

      final result = await controller.signInWithGoogle();

      expect(result, session);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNull);
      expect(storedTokens, ['token-123']);
      expect(
        controller.state.navigationRequest?.target,
        AuthNavigationTarget.home,
      );
    });

    test('stores user-facing error on failure', () async {
      when(() => mockSignInWithGoogle()).thenThrow(Exception('Google failed'));

      final result = await controller.signInWithGoogle();

      expect(result, isNull);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, 'Google failed');
      expect(storedTokens, isEmpty);
    });

    test('routes new users to username flow', () async {
      const newUserSession = AuthSessionResult(
        token: 'token-456',
        requiresUsername: true,
        hasPasskey: false,
      );
      when(() => mockSignInWithGoogle())
          .thenAnswer((_) async => newUserSession);

      await controller.signInWithGoogle();

      expect(
        controller.state.navigationRequest?.target,
        AuthNavigationTarget.username,
      );
      expect(
        controller.state.navigationRequest?.showPasskeyPromptAfterCompletion,
        true,
      );
    });

    test(
        'routes existing users without a passkey to passkey prompt when available',
        () async {
      canOfferPasskey = true;
      when(() => mockSignInWithGoogle()).thenAnswer((_) async => session);

      await controller.signInWithGoogle();

      expect(
        controller.state.navigationRequest?.target,
        AuthNavigationTarget.passkeyPrompt,
      );
    });
  });

  group('signInWithPasskey', () {
    test('tracks the active action while running', () async {
      when(() => mockSignInWithPasskey()).thenAnswer((_) async => session);

      final future = controller.signInWithPasskey();

      expect(controller.state.activeAction, AuthAction.signInWithPasskey);
      await future;
      expect(controller.state.activeAction, isNull);
    });
  });

  group('registerPasskey', () {
    test('returns updated security state on success', () async {
      when(() => mockRegisterPasskey()).thenAnswer((_) async => securityStatus);

      final result = await controller.registerPasskey();

      expect(result, securityStatus);
      verify(() => mockRegisterPasskey()).called(1);
    });
  });

  group('clearError', () {
    test('removes an existing error message', () async {
      when(() => mockSignInWithGoogle())
          .thenThrow(Exception('temporary issue'));

      await controller.signInWithGoogle();
      expect(controller.state.errorMessage, isNotNull);

      controller.clearError();

      expect(controller.state.errorMessage, isNull);
    });
  });

  group('consumeNavigation', () {
    test('clears an existing navigation request', () async {
      when(() => mockSignInWithGoogle()).thenAnswer((_) async => session);

      await controller.signInWithGoogle();
      expect(controller.state.navigationRequest, isNotNull);

      controller.consumeNavigation();

      expect(controller.state.navigationRequest, isNull);
    });
  });
}
