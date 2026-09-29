import '../../domain/entities/auth_result.dart';

AuthSessionResult authSessionResultFromJson(Map<String, dynamic> json) {
  return AuthSessionResult(
    token: json['token'] as String? ?? '',
    requiresUsername: json['requiresUsername'] as bool? ?? false,
    hasPasskey: json['hasPasskey'] as bool? ?? false,
  );
}

AuthSecurityStatus authSecurityStatusFromJson(Map<String, dynamic> json) {
  return AuthSecurityStatus(
    hasPasskey: json['hasPasskey'] as bool? ?? false,
  );
}

PasskeySummary passkeySummaryFromJson(Map<String, dynamic> json) {
  DateTime? parseMillis(dynamic value) {
    return value is num
        ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
        : null;
  }

  return PasskeySummary(
    id: json['id']?.toString() ?? '',
    deviceType: json['deviceType'] as String? ?? 'unknown',
    backedUp: json['backedUp'] as bool? ?? false,
    createdAt: parseMillis(json['createdAt']),
    lastUsedAt: parseMillis(json['lastUsedAt']),
  );
}
