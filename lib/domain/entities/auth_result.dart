enum AuthProvider {
  apple,
  google;

  String get apiValue => name;

  String get label {
    switch (this) {
      case AuthProvider.apple:
        return 'Apple';
      case AuthProvider.google:
        return 'Google';
    }
  }
}

class AuthSessionResult {
  final String token;
  final bool requiresUsername;
  final bool hasPasskey;

  const AuthSessionResult({
    required this.token,
    required this.requiresUsername,
    required this.hasPasskey,
  });
}

class LinkedIdentity {
  final AuthProvider provider;
  final String email;
  final bool emailVerified;
  final bool isPrivateRelay;
  final int linkedAt;
  final int lastUsedAt;

  const LinkedIdentity({
    required this.provider,
    required this.email,
    required this.emailVerified,
    required this.isPrivateRelay,
    required this.linkedAt,
    required this.lastUsedAt,
  });
}

class AuthSecurityStatus {
  final bool hasPasskey;
  final List<LinkedIdentity> linkedProviders;

  const AuthSecurityStatus({
    required this.hasPasskey,
    required this.linkedProviders,
  });
}
