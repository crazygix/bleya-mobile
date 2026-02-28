/// Domain entity for UserProfile - pure business object, no JSON parsing
class UserProfile {
  final String id;
  final String? username;
  final String? bio;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserProfile({
    required this.id,
    this.username,
    this.bio,
    this.profileImageUrl,
    this.createdAt,
    this.lastLogin,
  });
}
