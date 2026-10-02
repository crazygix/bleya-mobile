import 'package:bleya/utils/app_errors.dart';
import 'package:bleya/utils/auth_error_messages.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:passkeys/exceptions.dart' as passkey;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// The copy the caller picked for its action.
const _fallback = "Sign-in didn't finish. Try again?";

/// An Android failure the passkeys plugin passes on with its platform code.
const _androidSecurityError = 'android-unhandled: '
    'androidx.credentials.TYPE_CREATE_PUBLIC_KEY_CREDENTIAL_DOM_EXCEPTION/'
    'androidx.credentials.TYPE_SECURITY_ERROR';

/// Each failure, and what the user sees for it.
final _cases = <(String, Object, String)>[
  // The user cancelled: nothing shows.
  (
    'Google cancelled',
    const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
    '',
  ),
  (
    'Google interrupted',
    const GoogleSignInException(code: GoogleSignInExceptionCode.interrupted),
    '',
  ),
  (
    'Apple cancelled',
    const SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.canceled,
      message: 'The operation couldn’t be completed. (1001)',
    ),
    '',
  ),
  ('passkey cancelled', passkey.PasskeyAuthCancelledException(), ''),

  // The server's own message.
  (
    'an API error',
    ForbiddenError(
      message: 'Account suspended',
      userMessage: 'Your account is suspended until October 9, 2026.',
    ),
    'Your account is suspended until October 9, 2026.',
  ),
  (
    'no connection',
    NetworkError(message: 'Network connection error'),
    'Connection issue. Check your internet and try again?',
  ),

  // Fixed copy.
  (
    'Google misconfigured',
    const GoogleSignInException(
      code: GoogleSignInExceptionCode.providerConfigurationError,
      description: 'Developer console is not set up correctly.',
    ),
    "Google sign-in isn't available right now. Try another way to sign in.",
  ),
  (
    'Google client misconfigured',
    const GoogleSignInException(
      code: GoogleSignInExceptionCode.clientConfigurationError,
    ),
    "Google sign-in isn't available right now. Try another way to sign in.",
  ),
  (
    'Apple not supported',
    const SignInWithAppleNotSupportedException(message: 'iOS 12'),
    'Apple sign-in is not available on this device.',
  ),
  (
    'no passkey on the device',
    passkey.NoCredentialsAvailableException(),
    'No passkey was found for this account on this device.',
  ),
  (
    'passkey already on the device',
    passkey.ExcludeCredentialsCanNotBeRegisteredException(),
    'This device already has a passkey for your account.',
  ),
  (
    'no Google account',
    passkey.MissingGoogleSignInException(),
    'Sign in to a Google account on this device to use passkeys.',
  ),
  (
    'sync account unavailable',
    passkey.SyncAccountNotAvailableException(),
    'Sign in to a Google account on this device to use passkeys.',
  ),
  (
    'no passkey provider',
    passkey.NoCreateOptionException('No create options available.'),
    'Turn on a passkey provider in your device settings, then try again.',
  ),
  (
    'build not trusted for passkeys',
    passkey.DomainNotAssociatedException('Application is not associated'),
    "Passkeys aren't available right now. Try again later.",
  ),
  (
    'passkeys unsupported',
    passkey.PasskeyUnsupportedException(),
    "Passkeys aren't available on this device yet.",
  ),
  (
    'device not supported',
    passkey.DeviceNotSupportedException(),
    "Passkeys aren't available on this device yet.",
  ),
  (
    'passkey timeout',
    passkey.TimeoutException('[15] Flow has timed out.'),
    'That took too long. Try again.',
  ),

  // Anything else: the caller's fallback.
  (
    'Google unknown error',
    const GoogleSignInException(
      code: GoogleSignInExceptionCode.unknownError,
      description: 'Something internal',
    ),
    _fallback,
  ),
  (
    'Apple unknown error',
    const SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.unknown,
      message: 'The operation couldn’t be completed. (1000)',
    ),
    _fallback,
  ),
  (
    'Apple failed',
    const SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.failed,
      message: 'The operation couldn’t be completed. (1004)',
    ),
    _fallback,
  ),
  (
    'Apple credentials error',
    const SignInWithAppleCredentialsException(message: 'No credentials'),
    _fallback,
  ),
  (
    'Apple unknown platform error',
    UnknownSignInWithAppleException(
      platformException: PlatformException(code: 'web-flow-failed'),
    ),
    _fallback,
  ),
  (
    'unhandled passkey error',
    passkey.UnhandledAuthenticatorException(
      'ios-unhandled-WKErrorDomain',
      'The operation couldn’t be completed.',
      null,
    ),
    _fallback,
  ),
  (
    'malformed passkey challenge',
    passkey.MalformedBase64UrlChallenge(),
    _fallback,
  ),
  (
    'raw Android platform error',
    PlatformException(code: _androidSecurityError, message: 'Not trusted'),
    _fallback,
  ),
  (
    'plain exception',
    Exception('Google sign-in is not configured yet. Add '
        'GOOGLE_SERVER_CLIENT_ID.'),
    _fallback,
  ),
  ('programming error', StateError('Bad state'), _fallback),
  (
    'API error without copy',
    AppError(
      code: AppErrorCode.unknown,
      message: 'Internal detail',
      userMessage: ' ',
    ),
    _fallback,
  ),
];

void main() {
  for (final (name, error, expected) in _cases) {
    test('$name: ${expected.isEmpty ? 'shows nothing' : expected}', () {
      expect(authErrorMessage(error, fallback: _fallback), expected);
    });
  }

  test("never shows an error's own text", () {
    for (final (name, error, _) in _cases) {
      final message = authErrorMessage(error, fallback: _fallback);
      expect(message, isNot(contains('Exception')), reason: name);
      expect(message, isNot(contains('android-')), reason: name);
      final ownText = error.toString();
      if (ownText.isNotEmpty) {
        expect(message, isNot(contains(ownText)), reason: name);
      }
    }
  });
}
