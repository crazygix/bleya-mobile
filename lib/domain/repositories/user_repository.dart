import 'dart:io';
import '../entities/user_profile.dart';
import '../entities/blocked_user.dart';

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
  Future<List<BlockedUser>> getBlockedUsers();
  Future<void> deleteAccount();
  Future<Map<String, dynamic>> exportMyData();
  Future<void> blockUser(String userId);
  Future<void> unblockUser(String userId);
}
