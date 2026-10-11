import 'package:bleya/controllers/auth_controller.dart';
import 'package:bleya/domain/entities/analytics_event.dart';
import 'package:bleya/domain/entities/auth_result.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:passkeys/exceptions.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../mocks.dart';

void main() {
  late MockSignInWithGoogleUseCase mockSignInWithGoogle;
  late MockSignInWithAppleUseCase mockSignInWithApple;
  late MockSignInWithPasskeyUseCase mockSignInWithPasskey;
  late MockRegisterPasskeyUseCase mockRegisterPasskey;
  late MockRecordAnalyticsEventUseCase mockRecordAnalyticsEvent;
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

  setUpAll(() {
    registerFallbackValue(AppOpened());
  });

  setUp(() {
    mockSignInWithGoogle = MockSignInWithGoogleUseCase();
    mockSignInWithApple = MockSignInWithAppleUseCase();
    mockSignInWithPasskey = MockSignInWithPasskeyUseCase();
    mockRegisterPasskey = MockRegisterPasskeyUseCase();
    mockRecordAnalyticsEvent = MockRecordAnalyticsEventUseCase();
    when(() => mockRecordAnalyticsEvent(any())).thenReturn(null);
    storedTokens = [];
    canOfferPasskey = false;

    controller = AuthController(
      mockSignInWithGoogle,
      mockSignInWithApple,
      mockSignInWithPasskey,
      mockRegisterPasskey,
      mockRecordAnalyticsEvent,
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

    test("stores friendly copy on failure, never the error's text", () async {
      when(() => mockSignInWithGoogle()).thenThrow(Exception('Google failed'));

      final result = await controller.signInWithGoogle();

      expect(result, isNull);
      expect(controller.state.isLoading, false);
      expect(
        controller.state.errorMessage,
        "Google sign-in didn't finish. Try again?",
      );
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

  group('signInWithApple', () {
    test('a failure shows friendly copy instead of the plugin error', () async {
      when(() => mockSignInWithApple()).thenThrow(
        const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.unknown,
          message: 'The operation couldn’t be completed. (1000)',
        ),
      );

      final result = await controller.signInWithApple();

      expect(result, isNull);
      expect(
        controller.state.errorMessage,
        "Apple sign-in didn't finish. Try again?",
      );
    });

    test('a cancel shows nothing', () async {
      when(() => mockSignInWithApple()).thenThrow(
        const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'The operation couldn’t be completed. (1001)',
        ),
      );

      await controller.signInWithApple();

      expect(controller.state.errorMessage, isNull);
      expect(controller.state.isLoading, isFalse);
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

    test('a build not trusted for passkeys says passkeys are unavailable',
        () async {
      when(() => mockSignInWithPasskey()).thenThrow(
        DomainNotAssociatedException('Application is not associated'),
      );

      await controller.signInWithPasskey();

      expect(
        controller.state.errorMessage,
        "Passkeys aren't available right now. Try again later.",
      );
    });

    test('an unknown failure shows the passkey fallback', () async {
      when(() => mockSignInWithPasskey()).thenThrow(
        UnhandledAuthenticatorException('ios-unhandled', 'Internal', null),
      );

      await controller.signInWithPasskey();

      expect(
        controller.state.errorMessage,
        "Passkey sign-in didn't finish. Try again?",
      );
    });

    test('a cancel shows nothing', () async {
      when(() => mockSignInWithPasskey())
          .thenThrow(PasskeyAuthCancelledException());

      await controller.signInWithPasskey();

      expect(controller.state.errorMessage, isNull);
    });
  });

  group('registerPasskey', () {
    test('returns updated security state on success', () async {
      when(() => mockRegisterPasskey()).thenAnswer((_) async => securityStatus);

      final result = await controller.registerPasskey();

      expect(result, securityStatus);
      verify(() => mockRegisterPasskey()).called(1);
    });

    test('a raw platform error shows the add-a-passkey fallback', () async {
      when(() => mockRegisterPasskey()).thenThrow(
        PlatformException(
          code: 'android-unhandled: androidx.credentials.'
              'TYPE_CREATE_PUBLIC_KEY_CREDENTIAL_DOM_EXCEPTION/'
              'androidx.credentials.TYPE_UNKNOWN_ERROR',
          message: 'Something internal',
        ),
      );

      final result = await controller.registerPasskey();

      expect(result, isNull);
      expect(
        controller.state.errorMessage,
        "Couldn't add a passkey. Try again?",
      );
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

  group('analytics', () {
    /// What the controller reported, in order.
    List<AnalyticsEvent> recorded() =>
        verify(() => mockRecordAnalyticsEvent(captureAny()))
            .captured
            .cast<AnalyticsEvent>();

    DioException dioError({int? status}) {
      final options = RequestOptions(path: '/auth/provider-sign-in');
      return DioException(
        requestOptions: options,
        response: status == null
            ? null
            : Response(requestOptions: options, statusCode: status),
        type: status == null
            ? DioExceptionType.connectionError
            : DioExceptionType.badResponse,
      );
    }

    test('a sign-in that works reports only that it started', () async {
      when(() => mockSignInWithGoogle()).thenAnswer((_) async => session);

      await controller.signInWithGoogle();

      final events = recorded();
      expect(events, hasLength(1));
      expect(events.single, isA<SignInStarted>());
      expect((events.single as SignInStarted).method, SignInMethod.google);
    });

    test('closing the sheet reports a cancel', () async {
      when(() => mockSignInWithApple()).thenThrow(
        const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'The user canceled.',
        ),
      );

      await controller.signInWithApple();

      final events = recorded();
      expect(events.map((event) => event.runtimeType),
          [SignInStarted, SignInCancelled]);
      expect((events.last as SignInCancelled).method, SignInMethod.apple);
    });

    test("a provider failure reports the provider's code", () async {
      when(() => mockSignInWithGoogle()).thenThrow(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
        ),
      );

      await controller.signInWithGoogle();

      final failure = recorded().last as SignInFailed;
      expect(failure.method, SignInMethod.google);
      expect(failure.reason, 'google:clientConfigurationError');
    });

    test('a failure the backend answered is left to the backend', () async {
      when(() => mockSignInWithGoogle()).thenThrow(
        UnauthorizedError(originalError: dioError(status: 401)),
      );

      await controller.signInWithGoogle();

      expect(recorded().map((event) => event.runtimeType), [SignInStarted]);
    });

    test('a request that never got through reports why', () async {
      when(() => mockSignInWithPasskey())
          .thenThrow(NetworkError(originalError: dioError()));

      await controller.signInWithPasskey();

      final failure = recorded().last as SignInFailed;
      expect(failure.method, SignInMethod.passkey);
      expect(failure.reason, 'network:networkError');
    });

    test('adding a passkey is not a sign-in', () async {
      when(() => mockRegisterPasskey()).thenAnswer((_) async => securityStatus);

      await controller.registerPasskey();

      verifyNever(() => mockRecordAnalyticsEvent(any()));
    });
  });
}
