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

/// A passkey registered to the account, as listed in Settings.
class PasskeySummary {
  final String id;

  /// WebAuthn device type: `multiDevice` passkeys sync between devices (e.g.
  /// iCloud Keychain, Google Password Manager); `singleDevice` ones don't.
  final String deviceType;
  final bool backedUp;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  const PasskeySummary({
    required this.id,
    required this.deviceType,
    required this.backedUp,
    required this.createdAt,
    required this.lastUsedAt,
  });

  bool get isSynced => backedUp || deviceType == 'multiDevice';
}
