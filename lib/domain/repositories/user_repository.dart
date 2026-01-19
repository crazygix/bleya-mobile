import 'dart:io';

/// Domain repository interface for user operations
/// Use cases depend on this interface, not concrete implementations
abstract class UserRepository {
  Future<Map<String, dynamic>> getProfile();
  Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? bio,
  });
  Future<Map<String, dynamic>> uploadProfileImage(File imageFile);
  Future<Map<String, dynamic>> getUserById(String userId);
}
