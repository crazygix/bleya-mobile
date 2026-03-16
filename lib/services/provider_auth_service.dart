import 'dart:convert';
import 'dart:math';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../config/environment.dart';
import '../domain/entities/auth_result.dart';
import '../platform/ui_platform.dart';

class ProviderAuthCredential {
  final AuthProvider provider;
  final String idToken;
  final String? rawNonce;

  const ProviderAuthCredential({
    required this.provider,
    required this.idToken,
    this.rawNonce,
  });
}

class ProviderAuthService {
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;

  ProviderAuthService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  Future<void> _ensureGoogleInitialized() {
    return _googleInitialization ??= _googleSignIn.initialize(
      clientId: EnvironmentConfig.googleIosClientId,
      serverClientId: EnvironmentConfig.googleServerClientId,
    );
  }

  Future<ProviderAuthCredential> signInWithGoogle() async {
    if ((EnvironmentConfig.googleServerClientId ?? '').isEmpty) {
      throw Exception(
        'Google sign-in is not configured yet. Add GOOGLE_SERVER_CLIENT_ID.',
      );
    }

    await _ensureGoogleInitialized();

    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google sign-in did not return an identity token.');
    }

    return ProviderAuthCredential(
      provider: AuthProvider.google,
      idToken: idToken,
    );
  }

  Future<bool> isAppleSignInAvailable() => SignInWithApple.isAvailable();

  Future<ProviderAuthCredential> signInWithApple() async {
    final rawNonce = _generateNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: rawNonce,
      state: _generateNonce(),
      webAuthenticationOptions: isAndroidPlatform()
          ? WebAuthenticationOptions(
              clientId: _requireAppleServiceId(),
              redirectUri: EnvironmentConfig.appleRedirectUri,
            )
          : null,
    );

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Apple sign-in did not return an identity token.');
    }

    return ProviderAuthCredential(
      provider: AuthProvider.apple,
      idToken: idToken,
      rawNonce: rawNonce,
    );
  }

  Future<void> clearCachedProviderSession() async {
    if (_googleInitialization == null) {
      return;
    }

    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } catch (_) {
      // Local provider session cleanup should not block logout.
    }
  }

  String _requireAppleServiceId() {
    final value = EnvironmentConfig.appleServiceId;
    if (value == null || value.isEmpty) {
      throw Exception(
        'Apple sign-in on Android is not configured yet. Add APPLE_SERVICE_ID.',
      );
    }
    return value;
  }

  String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
