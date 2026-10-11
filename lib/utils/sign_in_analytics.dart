import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:passkeys/exceptions.dart' as passkey;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../domain/entities/analytics_event.dart';
import 'app_errors.dart';

/// The analytics event for a sign-in with [method] that failed with [error],
/// or null when the backend answered the request: it records those failures
/// itself, so reporting them here would count them twice.
///
/// Reported: the user closing the provider's sheet (cancelled), the
/// provider's SDK failing, and requests that never got an answer from the
/// backend (offline, timeouts, or a gateway error while it was down).
AnalyticsEvent? signInFailureEvent(SignInMethod method, Object error) {
  if (error is AppError) {
    final original = error.originalError;
    if (original is! DioException) {
      return SignInFailed(method, 'app:${error.code.name}');
    }
    final status = original.response?.statusCode;
    if (status == null) {
      return SignInFailed(method, 'network:${error.code.name}');
    }
    // 502-504 come from the proxies in front of the backend, not from it.
    return status >= 502 ? SignInFailed(method, 'http:$status') : null;
  }

  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted =>
        SignInCancelled(method),
      _ => SignInFailed(method, 'google:${error.code.name}'),
    };
  }

  if (error is SignInWithAppleAuthorizationException) {
    return error.code == AuthorizationErrorCode.canceled
        ? SignInCancelled(method)
        : SignInFailed(method, 'apple:${error.code.name}');
  }
  if (error is SignInWithAppleNotSupportedException) {
    return SignInFailed(method, 'apple:notSupported');
  }

  final passkeyReason = switch (error) {
    passkey.PasskeyAuthCancelledException() => null,
    passkey.NoCredentialsAvailableException() => 'noCredentials',
    passkey.DomainNotAssociatedException() => 'domainNotAssociated',
    passkey.PasskeyUnsupportedException() => 'unsupported',
    passkey.DeviceNotSupportedException() => 'deviceNotSupported',
    passkey.MissingGoogleSignInException() => 'missingGoogleSignIn',
    passkey.SyncAccountNotAvailableException() => 'syncAccountNotAvailable',
    passkey.TimeoutException() => 'timeout',
    _ => '',
  };
  if (passkeyReason == null) {
    return SignInCancelled(method);
  }
  if (passkeyReason.isNotEmpty) {
    return SignInFailed(method, 'passkey:$passkeyReason');
  }

  if (error is PlatformException) {
    return SignInFailed(method, 'platform:${error.code}');
  }
  return SignInFailed(method, 'unknown');
}
