import '../../domain/entities/auth_result.dart';

AuthProvider _parseProvider(String value) {
  switch (value) {
    case 'apple':
      return AuthProvider.apple;
    case 'google':
      return AuthProvider.google;
    default:
      throw FormatException('Unsupported auth provider: $value');
  }
}

AuthSessionResult authSessionResultFromJson(Map<String, dynamic> json) {
  return AuthSessionResult(
    token: json['token'] as String? ?? '',
    requiresUsername: json['requiresUsername'] as bool? ?? false,
    hasPasskey: json['hasPasskey'] as bool? ?? false,
  );
}

LinkedIdentity linkedIdentityFromJson(Map<String, dynamic> json) {
  return LinkedIdentity(
    provider: _parseProvider(json['provider'] as String? ?? ''),
    email: json['email'] as String? ?? '',
    emailVerified: json['emailVerified'] as bool? ?? false,
    isPrivateRelay: json['isPrivateRelay'] as bool? ?? false,
    linkedAt: json['linkedAt'] as int? ?? 0,
    lastUsedAt: json['lastUsedAt'] as int? ?? 0,
  );
}

AuthSecurityStatus authSecurityStatusFromJson(Map<String, dynamic> json) {
  final linkedProviders = (json['linkedProviders'] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(linkedIdentityFromJson)
      .toList(growable: false);

  return AuthSecurityStatus(
    hasPasskey: json['hasPasskey'] as bool? ?? false,
    linkedProviders: linkedProviders,
  );
}
