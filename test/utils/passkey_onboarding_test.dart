import 'package:bleya/controllers/auth_controller.dart';
import 'package:bleya/domain/entities/auth_result.dart';
import 'package:bleya/utils/passkey_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const securityStatus = AuthSecurityStatus(
    hasPasskey: true,
  );

  late bool invalidated;
  late bool clearedError;
  late List<String> notices;

  setUp(() {
    invalidated = false;
    clearedError = false;
    notices = [];
  });

  Future<void> offerPasskey({
    required AuthSecurityStatus? result,
    String? errorMessage,
  }) {
    return maybeRegisterOnboardingPasskey(
      registerPasskey: () async => result,
      invalidateSecurityStatus: () => invalidated = true,
      readAuthState: () => AuthState(errorMessage: errorMessage),
      clearAuthError: () => clearedError = true,
      showNotice: notices.add,
    );
  }

  test('invalidates security status after successful onboarding registration',
      () async {
    await offerPasskey(result: securityStatus);

    expect(invalidated, isTrue);
    expect(clearedError, isFalse);
    expect(notices, isEmpty);
  });

  test('shows nothing when the native passkey prompt is dismissed', () async {
    await offerPasskey(result: null);

    expect(invalidated, isFalse);
    expect(notices, isEmpty);
  });

  test(
      'a failure only says a passkey can be added later, and clears the '
      'error', () async {
    await offerPasskey(
      result: null,
      errorMessage: "Passkeys aren't available right now. Try again later.",
    );

    expect(invalidated, isFalse);
    expect(clearedError, isTrue);
    expect(notices, ['You can add a passkey later in Settings.']);
  });
}
