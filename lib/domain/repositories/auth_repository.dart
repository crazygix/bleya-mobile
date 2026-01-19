/// Domain repository interface for authentication
/// Use cases depend on this interface, not concrete implementations
abstract class AuthRepository {
  Future<Map<String, dynamic>> requestCode({required String phone});
  Future<Map<String, dynamic>> resendCode({required String phone});
  Future<Map<String, dynamic>> verifyCode({
    required String phone,
    required String code,
  });
  Future<bool> checkUsername({required String username});
  Future<void> setUsername({required String username});
  Future<Map<String, dynamic>> getMyInfo();
  Future<String> refresh();
  Future<void> logout();
}
