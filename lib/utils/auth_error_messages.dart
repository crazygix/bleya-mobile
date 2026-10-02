import 'package:google_sign_in/google_sign_in.dart';
import 'package:passkeys/exceptions.dart' as passkey;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'app_errors.dart';

/// Shown when Google sign-in can't run on this build.
const _googleSignInUnavailable =
    "Google sign-in isn't available right now. Try another way to sign in.";

/// Shown when this build can't use passkeys for Bleya's domain.
const _passkeysUnavailable =
    "Passkeys aren't available right now. Try again later.";

/// What to tell the user when signing in, or adding or using a passkey, fails
/// with [error]:
/// - nothing ('') when they cancelled;
/// - the server's message for an [AppError];
/// - fixed copy for the Google, Apple and passkey failures it knows;
/// - [fallback] for anything else.
///
/// It never returns the error's own text, which is written for developers.
String authErrorMessage(Object error, {required String fallback}) {
  if (error is AppError) {
    final message = error.getUserMessage().trim();
    return message.isEmpty ? fallback : message;
  }

  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted =>
        '',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        _googleSignInUnavailable,
      _ => fallback,
    };
  }

  if (error is SignInWithAppleAuthorizationException) {
    return error.code == AuthorizationErrorCode.canceled ? '' : fallback;
  }
  if (error is SignInWithAppleNotSupportedException) {
    return 'Apple sign-in is not available on this device.';
  }

  return switch (error) {
    passkey.PasskeyAuthCancelledException() => '',
    passkey.NoCredentialsAvailableException() =>
      'No passkey was found for this account on this device.',
    passkey.ExcludeCredentialsCanNotBeRegisteredException() =>
      'This device already has a passkey for your account.',
    passkey.MissingGoogleSignInException() ||
    passkey.SyncAccountNotAvailableException() =>
      'Sign in to a Google account on this device to use passkeys.',
    passkey.NoCreateOptionException() =>
      'Turn on a passkey provider in your device settings, then try again.',
    passkey.DomainNotAssociatedException() => _passkeysUnavailable,
    passkey.PasskeyUnsupportedException() ||
    passkey.DeviceNotSupportedException() =>
      "Passkeys aren't available on this device yet.",
    passkey.TimeoutException() => 'That took too long. Try again.',
    _ => fallback,
  };
}
