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

class AuthSecurityStatus {
  final bool hasPasskey;

  const AuthSecurityStatus({
    required this.hasPasskey,
  });
}
