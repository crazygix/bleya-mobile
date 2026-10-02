import 'package:flutter/services.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import '../platform/ui_platform.dart';

class PasskeyRequestOptions {
  final String challengeId;
  final Map<String, dynamic> payload;

  const PasskeyRequestOptions({
    required this.challengeId,
    required this.payload,
  });
}

class PasskeyAuthService {
  final PasskeyAuthenticator _authenticator;

  PasskeyAuthService({PasskeyAuthenticator? authenticator})
      : _authenticator = authenticator ?? PasskeyAuthenticator();

  Future<bool> isAvailable() async {
    if (!isAndroidPlatform() && !isIosPlatform()) {
      return false;
    }

    if (isAndroidPlatform()) {
      final availability = await _authenticator.getAvailability().android();
      return availability.hasPasskeySupport;
    }

    final availability = await _authenticator.getAvailability().iOS();
    return availability.hasPasskeySupport && availability.hasBiometrics;
  }

  Future<Map<String, dynamic>> register(PasskeyRequestOptions options) async {
    final request = RegisterRequestType.fromJson(options.payload);
    try {
      final response = await _authenticator.register(request);
      return response.toJson();
    } catch (error, stackTrace) {
      _throwTyped(error, stackTrace);
    }
  }

  Future<Map<String, dynamic>> authenticate(
    PasskeyRequestOptions options,
  ) async {
    final request = AuthenticateRequestType.fromJson(options.payload);
    try {
      final response = await _authenticator.authenticate(request);
      return response.toJson();
    } catch (error, stackTrace) {
      _throwTyped(error, stackTrace);
    }
  }

  /// Rethrows [error], with the type iOS uses where the passkeys plugin
  /// leaves an Android failure untyped.
  Never _throwTyped(Object error, StackTrace stackTrace) {
    Error.throwWithStackTrace(_typedAndroidError(error) ?? error, stackTrace);
  }

  /// The typed exception for an Android failure that reaches us by its
  /// platform code only, or null for any other error.
  static AuthenticatorException? _typedAndroidError(Object error) {
    final String code;
    final String? message;
    if (error is PlatformException) {
      code = error.code;
      message = error.message;
    } else if (error is UnhandledAuthenticatorException) {
      code = error.code;
      message = error.message;
    } else {
      return null;
    }

    // Android's security error: this build isn't trusted for the passkey
    // domain, as iOS reports with domain-not-associated.
    if (code.contains('TYPE_SECURITY_ERROR')) {
      return DomainNotAssociatedException(message);
    }
    return switch (code) {
      'android-no-create-option' => NoCreateOptionException(message),
      'android-sync-account-not-available' =>
        SyncAccountNotAvailableException(),
      _ => null,
    };
  }
}
