class BlockedUser {
  final String id;
  final String username;
  final String bio;
  final String? profileImageUrl;
  final DateTime? blockedAt;

  const BlockedUser({
    required this.id,
    required this.username,
    required this.bio,
    required this.profileImageUrl,
    required this.blockedAt,
  });
}
