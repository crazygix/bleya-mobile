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
    final response = await _authenticator.register(request);
    return response.toJson();
  }

  Future<Map<String, dynamic>> authenticate(
    PasskeyRequestOptions options,
  ) async {
    final request = AuthenticateRequestType.fromJson(options.payload);
    final response = await _authenticator.authenticate(request);
    return response.toJson();
  }
}
