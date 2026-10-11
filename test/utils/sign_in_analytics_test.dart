import 'package:bleya/domain/entities/analytics_event.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:bleya/utils/sign_in_analytics.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:passkeys/exceptions.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  DioException dioError({int? status}) {
    final options = RequestOptions(path: '/auth/provider-sign-in');
    return DioException(
      requestOptions: options,
      response: status == null
          ? null
          : Response(requestOptions: options, statusCode: status),
    );
  }

  String? reasonOf(AnalyticsEvent? event) =>
      event is SignInFailed ? event.reason : null;

  group('left to the backend, which answered', () {
    for (final status in [400, 401, 403, 429, 500]) {
      test('$status', () {
        expect(
          signInFailureEvent(
            SignInMethod.google,
            AppError(
              code: AppErrorCode.unknown,
              message: 'x',
              originalError: dioError(status: status),
            ),
          ),
          isNull,
        );
      });
    }
  });

  test('a gateway error while the backend was down is reported', () {
    final event = signInFailureEvent(
      SignInMethod.apple,
      ServerError(message: 'x', originalError: dioError(status: 502)),
    );

    expect(reasonOf(event), 'http:502');
  });

  test('a request that never got through is reported', () {
    final event = signInFailureEvent(
      SignInMethod.passkey,
      NetworkError(originalError: dioError()),
    );

    expect(event, isA<SignInFailed>());
    expect((event as SignInFailed).method, SignInMethod.passkey);
    expect(event.reason, 'network:networkError');
  });

  test('cancels', () {
    expect(
      signInFailureEvent(
        SignInMethod.google,
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      ),
      isA<SignInCancelled>(),
    );
    expect(
      signInFailureEvent(
        SignInMethod.apple,
        const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'canceled',
        ),
      ),
      isA<SignInCancelled>(),
    );
    expect(
      signInFailureEvent(SignInMethod.passkey, PasskeyAuthCancelledException()),
      isA<SignInCancelled>(),
    );
  });

  test('provider failures carry the provider and its code', () {
    expect(
      reasonOf(signInFailureEvent(
        SignInMethod.google,
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.providerConfigurationError,
        ),
      )),
      'google:providerConfigurationError',
    );
    expect(
      reasonOf(signInFailureEvent(
        SignInMethod.apple,
        const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.failed,
          message: 'failed',
        ),
      )),
      'apple:failed',
    );
    expect(
      reasonOf(signInFailureEvent(
        SignInMethod.passkey,
        DomainNotAssociatedException('not associated'),
      )),
      'passkey:domainNotAssociated',
    );
    expect(
      reasonOf(signInFailureEvent(
        SignInMethod.google,
        PlatformException(code: 'sign_in_failed'),
      )),
      'platform:sign_in_failed',
    );
    expect(
      reasonOf(signInFailureEvent(SignInMethod.google, Exception('?'))),
      'unknown',
    );
  });
}
