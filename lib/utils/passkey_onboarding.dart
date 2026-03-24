import '../controllers/auth_controller.dart';
import '../domain/entities/auth_result.dart';

typedef RegisterPasskey = Future<AuthSecurityStatus?> Function();
typedef InvalidateSecurityStatus = void Function();
typedef ReadAuthState = AuthState Function();
typedef ClearAuthError = void Function();
typedef ShowPasskeyOnboardingError = void Function(String message);

Future<void> maybeRegisterOnboardingPasskey({
  required RegisterPasskey registerPasskey,
  required InvalidateSecurityStatus invalidateSecurityStatus,
  required ReadAuthState readAuthState,
  required ClearAuthError clearAuthError,
  required ShowPasskeyOnboardingError showError,
}) async {
  final result = await registerPasskey();

  if (result != null) {
    invalidateSecurityStatus();
    return;
  }

  final errorMessage = readAuthState().errorMessage?.trim() ?? '';
  if (errorMessage.isEmpty) {
    return;
  }

  showError('$errorMessage You can add a passkey later in Settings.');
  clearAuthError();
}
