import 'package:bleya/controllers/auth_controller.dart';
import 'package:bleya/domain/entities/auth_result.dart';
import 'package:bleya/utils/passkey_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const securityStatus = AuthSecurityStatus(
    hasPasskey: true,
  );

  test('invalidates security status after successful onboarding registration',
      () async {
    var invalidated = false;
    var clearedError = false;
    String? shownError;

    await maybeRegisterOnboardingPasskey(
      registerPasskey: () async => securityStatus,
      invalidateSecurityStatus: () => invalidated = true,
      readAuthState: () => AuthState(),
      clearAuthError: () => clearedError = true,
      showError: (message) => shownError = message,
    );

    expect(invalidated, isTrue);
    expect(clearedError, isFalse);
    expect(shownError, isNull);
  });

  test('does nothing when the native passkey prompt is dismissed', () async {
    var invalidated = false;
    var clearedError = false;
    String? shownError;

    await maybeRegisterOnboardingPasskey(
      registerPasskey: () async => null,
      invalidateSecurityStatus: () => invalidated = true,
      readAuthState: () => AuthState(),
      clearAuthError: () => clearedError = true,
      showError: (message) => shownError = message,
    );

    expect(invalidated, isFalse);
    expect(clearedError, isFalse);
    expect(shownError, isNull);
  });

  test('shows a follow-up error when passkey registration fails', () async {
    var invalidated = false;
    var clearedError = false;
    String? shownError;

    await maybeRegisterOnboardingPasskey(
      registerPasskey: () async => null,
      invalidateSecurityStatus: () => invalidated = true,
      readAuthState: () => AuthState(
        errorMessage: 'Passkeys are not configured for this build yet.',
      ),
      clearAuthError: () => clearedError = true,
      showError: (message) => shownError = message,
    );

    expect(invalidated, isFalse);
    expect(clearedError, isTrue);
    expect(
      shownError,
      'Passkeys are not configured for this build yet. '
      'You can add a passkey later in Settings.',
    );
  });
}
