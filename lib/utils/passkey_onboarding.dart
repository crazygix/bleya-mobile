import '../controllers/auth_controller.dart';
import '../domain/entities/auth_result.dart';

typedef RegisterPasskey = Future<AuthSecurityStatus?> Function();
typedef InvalidateSecurityStatus = void Function();
typedef ReadAuthState = AuthState Function();
typedef ClearAuthError = void Function();
typedef ShowPasskeyOnboardingNotice = void Function(String message);

/// Shown when the passkey offered after signing in couldn't be added. It
/// doesn't say why: the user didn't ask for a passkey, and Settings →
/// Passkeys explains when they add one there.
const passkeyOnboardingFailedMessage =
    'You can add a passkey later in Settings.';

/// Offers a passkey right after signing in or choosing a username. If adding
/// it fails, [showNotice] gets [passkeyOnboardingFailedMessage]; if the user
/// cancels, nothing shows. The failure's own message never shows, here or
/// later on the sign-in screen.
Future<void> maybeRegisterOnboardingPasskey({
  required RegisterPasskey registerPasskey,
  required InvalidateSecurityStatus invalidateSecurityStatus,
  required ReadAuthState readAuthState,
  required ClearAuthError clearAuthError,
  required ShowPasskeyOnboardingNotice showNotice,
}) async {
  final result = await registerPasskey();

  if (result != null) {
    invalidateSecurityStatus();
    return;
  }

  // A cancel leaves no error behind; a failure does.
  final failed = (readAuthState().errorMessage?.trim() ?? '').isNotEmpty;
  clearAuthError();
  if (failed) {
    showNotice(passkeyOnboardingFailedMessage);
  }
}
