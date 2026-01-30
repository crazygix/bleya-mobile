import 'dart:io';
import '../entities/user_profile.dart';

/// Domain repository interface for user operations
/// Use cases depend on this interface, not concrete implementations
abstract class UserRepository {
  Future<UserProfile> getProfile();
  Future<UserProfile> updateProfile({
    String? username,
    String? bio,
  });
  Future<UserProfile> uploadProfileImage(File imageFile);
  Future<UserProfile> getUserById(String userId);
}
