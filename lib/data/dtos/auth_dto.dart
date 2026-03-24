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
