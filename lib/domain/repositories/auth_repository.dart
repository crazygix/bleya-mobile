import '../entities/auth_result.dart';
import '../entities/user_profile.dart';

/// Domain repository interface for authentication
/// Use cases depend on this interface, not concrete implementations
abstract class AuthRepository {
  Future<CodeRequestResult> requestCode({required String phone});
  Future<CodeRequestResult> resendCode({required String phone});
  Future<VerifyCodeResult> verifyCode({
    required String phone,
    required String code,
  });
  Future<bool> checkUsername({required String username});
  Future<void> setUsername({required String username});
  Future<UserProfile> getMyInfo();
  Future<String> refresh();
  Future<void> logout();
}
