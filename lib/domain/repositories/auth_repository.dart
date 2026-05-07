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
  Future<bool> hasRegisteredPasskeyOnDevice();
  Future<bool> checkUsername({required String username});
  Future<UserProfile> setUsername({required String username});
  Future<UserProfile> getMyInfo();
  Future<String> refresh();
  Future<void> logout();
}
