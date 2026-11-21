import '../entities/auth_result.dart';
import '../entities/user_profile.dart';

/// Domain repository interface for authentication
/// Use cases depend on this interface, not concrete implementations
abstract class AuthRepository {
  Future<AuthSessionResult> signInWithGoogle();
  Future<AuthSessionResult> signInWithApple();
  Future<AuthSessionResult> signInWithPasskey();
  Future<AuthSecurityStatus> getSecurityStatus();
  Future<AuthSecurityStatus> registerPasskey();
  Future<List<PasskeySummary>> listPasskeys();
  Future<AuthSecurityStatus> deletePasskey(String passkeyId);
  Future<bool> hasRegisteredPasskeyOnDevice();
  Future<bool> checkUsername({required String username});
  Future<UserProfile> setUsername({required String username});

  /// Forgets that this device has a passkey for sign-in, so the sign-in
  /// screen stops offering one, e.g. after the account was deleted.
  Future<void> forgetRegisteredPasskey();
}
