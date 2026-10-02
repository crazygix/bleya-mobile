import 'package:bleya/data/repositories/auth_repository_impl.dart';
import 'package:bleya/domain/entities/auth_result.dart';
import 'package:bleya/services/passkey_auth_service.dart';
import 'package:bleya/services/provider_auth_service.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:passkeys/exceptions.dart';

import '../../fakes/fake_http_adapter.dart';
import '../../fakes/in_memory_secure_storage.dart';
import '../../fixtures/api_fixtures.dart';

class _MockProviderAuthService extends Mock implements ProviderAuthService {}

class _MockPasskeyAuthService extends Mock implements PasskeyAuthService {}

const _passkeyFlag = 'has_registered_passkey';

/// What the passkeys plugin returns for a sign-in on the device.
const _assertion = {
  'id': 'credential-1',
  'rawId': 'credential-1',
  'type': 'public-key',
  'response': {
    'clientDataJSON': 'client-data',
    'authenticatorData': 'authenticator-data',
    'signature': 'signature',
    'userHandle': 'user-handle',
  },
};

/// What the passkeys plugin returns for a new passkey.
const _attestation = {
  'id': 'credential-2',
  'rawId': 'credential-2',
  'type': 'public-key',
  'response': {
    'clientDataJSON': 'client-data',
    'attestationObject': 'attestation-object',
  },
};

void main() {
  setUpAll(() {
    registerFallbackValue(
      const PasskeyRequestOptions(challengeId: '', payload: {}),
    );
  });

  late FakeHttpAdapter server;
  late InMemorySecureStorage storage;
  late _MockProviderAuthService providerAuth;
  late _MockPasskeyAuthService passkeys;
  late AuthRepositoryImpl repository;

  /// Answers requests with [handler].
  void serve(FakeHttpHandler handler) {
    server = FakeHttpAdapter(handler);
    repository = AuthRepositoryImpl(
      fakeDio(server),
      storage,
      providerAuth,
      passkeys,
    );
  }

  /// Answers each path with its response; anything else is not found.
  void route(Map<String, Object> responses) {
    serve((options) async {
      final body = responses[options.path];
      if (body == null) {
        return apiErrorResponse(
          404,
          'NOT_FOUND',
          "We couldn't find what you were looking for.",
        );
      }
      return jsonResponse(200, body);
    });
  }

  setUp(() {
    storage = InMemorySecureStorage();
    providerAuth = _MockProviderAuthService();
    passkeys = _MockPasskeyAuthService();
    serve((_) async => jsonResponse(200, authSessionJson()));
  });

  group('provider sign-in', () {
    test('Google: POST /auth/provider-sign-in, then keeps the session',
        () async {
      when(() => providerAuth.signInWithGoogle()).thenAnswer(
        (_) async => const ProviderAuthCredential(
          provider: AuthProvider.google,
          idToken: 'google-id-token',
          rawNonce: 'google-nonce',
        ),
      );
      serve((_) async => jsonResponse(200, authSessionJson(hasPasskey: true)));

      final result = await repository.signInWithGoogle();

      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/auth/provider-sign-in');
      expect(request.data, {
        'provider': 'google',
        'idToken': 'google-id-token',
        'rawNonce': 'google-nonce',
        'platform': 'mobile',
      });
      expect(result.token, 'access-token-1');
      expect(result.requiresUsername, isFalse);
      expect(storage.values['auth_token'], 'access-token-1');
      expect(await repository.hasRegisteredPasskeyOnDevice(), isTrue);
    });

    test('an account without a passkey hides the passkey button', () async {
      await storage.write(key: _passkeyFlag, value: 'true');
      when(() => providerAuth.signInWithGoogle()).thenAnswer(
        (_) async => const ProviderAuthCredential(
          provider: AuthProvider.google,
          idToken: 'google-id-token',
          rawNonce: 'google-nonce',
        ),
      );
      serve((_) async => jsonResponse(
            200,
            authSessionJson(requiresUsername: true),
          ));

      final result = await repository.signInWithGoogle();

      expect(result.requiresUsername, isTrue);
      expect(await repository.hasRegisteredPasskeyOnDevice(), isFalse);
    });

    test('Apple: sends the authorization code with the token and nonce',
        () async {
      when(() => providerAuth.signInWithApple()).thenAnswer(
        (_) async => const ProviderAuthCredential(
          provider: AuthProvider.apple,
          idToken: 'apple-id-token',
          rawNonce: 'apple-nonce',
          authorizationCode: 'apple-authorization-code',
        ),
      );

      await repository.signInWithApple();

      expect(server.requests.single.data, {
        'provider': 'apple',
        'idToken': 'apple-id-token',
        'rawNonce': 'apple-nonce',
        'authorizationCode': 'apple-authorization-code',
        'platform': 'mobile',
      });
    });

    test('Apple: leaves out a missing nonce and code', () async {
      when(() => providerAuth.signInWithApple()).thenAnswer(
        (_) async => const ProviderAuthCredential(
          provider: AuthProvider.apple,
          idToken: 'apple-id-token',
        ),
      );

      await repository.signInWithApple();

      expect(server.requests.single.data, {
        'provider': 'apple',
        'idToken': 'apple-id-token',
        'platform': 'mobile',
      });
    });

    test('a banned account fails as forbidden, with the reason', () async {
      when(() => providerAuth.signInWithApple()).thenAnswer(
        (_) async => const ProviderAuthCredential(
          provider: AuthProvider.apple,
          idToken: 'apple-id-token',
        ),
      );
      serve((_) async => apiErrorResponse(
            403,
            'USER_BLOCKED',
            'Your account has been banned. Reason: Spam',
          ));

      await expectLater(
        repository.signInWithApple(),
        throwsA(
          isA<AppError>()
              .having((e) => e.code, 'code', AppErrorCode.forbidden)
              .having(
                (e) => e.getUserMessage(),
                'user message',
                'Your account has been banned. Reason: Spam',
              ),
        ),
      );
      expect(storage.values, isNot(contains('auth_token')));
    });
  });

  group('passkey sign-in', () {
    test('asks for options, signs in on the device, then verifies', () async {
      when(() => passkeys.authenticate(any()))
          .thenAnswer((_) async => Map<String, dynamic>.from(_assertion));
      route({
        '/auth/passkeys/authentication/options':
            passkeyAuthenticationOptionsJson(),
        '/auth/passkeys/authentication/verify':
            authSessionJson(hasPasskey: true),
      });

      final result = await repository.signInWithPasskey();

      expect(
        server.requests.map((r) => '${r.method} ${r.path}'),
        [
          'POST /auth/passkeys/authentication/options',
          'POST /auth/passkeys/authentication/verify',
        ],
      );
      expect(server.requests.first.data, isNull);
      final options = verify(() => passkeys.authenticate(captureAny()))
          .captured
          .single as PasskeyRequestOptions;
      expect(options.challengeId, FixtureIds.challenge);
      expect(options.payload, passkeyAuthenticationOptionsJson()['options']);
      expect(server.requests.last.data, {
        'challengeId': FixtureIds.challenge,
        'response': _assertion,
      });
      expect(result.token, 'access-token-1');
      expect(storage.values['auth_token'], 'access-token-1');
      expect(await repository.hasRegisteredPasskeyOnDevice(), isTrue);
    });

    test('no passkey on the device: hides the button and rethrows', () async {
      await storage.write(key: _passkeyFlag, value: 'true');
      when(() => passkeys.authenticate(any()))
          .thenThrow(NoCredentialsAvailableException());
      route({
        '/auth/passkeys/authentication/options':
            passkeyAuthenticationOptionsJson(),
      });

      await expectLater(
        repository.signInWithPasskey(),
        throwsA(isA<NoCredentialsAvailableException>()),
      );
      expect(await repository.hasRegisteredPasskeyOnDevice(), isFalse);
      expect(server.callsTo('/auth/passkeys/authentication/verify'), 0);
    });

    test('a build the domain does not trust: hides the button and rethrows',
        () async {
      await storage.write(key: _passkeyFlag, value: 'true');
      when(() => passkeys.authenticate(any()))
          .thenThrow(DomainNotAssociatedException('not associated'));
      route({
        '/auth/passkeys/authentication/options':
            passkeyAuthenticationOptionsJson(),
      });

      await expectLater(
        repository.signInWithPasskey(),
        throwsA(isA<DomainNotAssociatedException>()),
      );
      expect(await repository.hasRegisteredPasskeyOnDevice(), isFalse);
    });

    test('a passkey the server does not know fails as unauthorized', () async {
      when(() => passkeys.authenticate(any()))
          .thenAnswer((_) async => Map<String, dynamic>.from(_assertion));
      serve((options) async {
        if (options.path == '/auth/passkeys/authentication/options') {
          return jsonResponse(200, passkeyAuthenticationOptionsJson());
        }
        return apiErrorResponse(
          401,
          'UNAUTHORIZED',
          'No passkey found for that device.',
        );
      });

      await expectLater(
        repository.signInWithPasskey(),
        throwsA(isA<UnauthorizedError>().having(
          (e) => e.getUserMessage(),
          'user message',
          'No passkey found for that device.',
        )),
      );
      expect(storage.values, isNot(contains('auth_token')));
    });
  });

  test('GET /auth/security', () async {
    serve((_) async => jsonResponse(200, securityStatusJson(hasPasskey: true)));

    final status = await repository.getSecurityStatus();

    final request = server.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/auth/security');
    expect(status.hasPasskey, isTrue);
  });

  group('registerPasskey', () {
    test('asks for options, creates the passkey, then verifies', () async {
      when(() => passkeys.register(any()))
          .thenAnswer((_) async => Map<String, dynamic>.from(_attestation));
      route({
        '/auth/passkeys/registration/options': passkeyRegistrationOptionsJson(),
        '/auth/passkeys/registration/verify':
            securityStatusJson(hasPasskey: true),
      });

      final status = await repository.registerPasskey();

      expect(
        server.requests.map((r) => '${r.method} ${r.path}'),
        [
          'POST /auth/passkeys/registration/options',
          'POST /auth/passkeys/registration/verify',
        ],
      );
      final options = verify(() => passkeys.register(captureAny()))
          .captured
          .single as PasskeyRequestOptions;
      expect(options.challengeId, FixtureIds.challenge);
      expect(options.payload, passkeyRegistrationOptionsJson()['options']);
      expect(server.requests.last.data, {
        'challengeId': FixtureIds.challenge,
        'response': _attestation,
      });
      expect(status.hasPasskey, isTrue);
      expect(await repository.hasRegisteredPasskeyOnDevice(), isTrue);
    });

    test('a sign-in that is not recent fails as forbidden, with the reason',
        () async {
      serve((_) async => apiErrorResponse(
            403,
            'FORBIDDEN',
            'For your security, please sign in again before changing your '
                'passkeys.',
          ));

      await expectLater(
        repository.registerPasskey(),
        throwsA(
          isA<AppError>()
              .having((e) => e.code, 'code', AppErrorCode.forbidden)
              .having(
                (e) => e.getUserMessage(),
                'user message',
                'For your security, please sign in again before changing '
                    'your passkeys.',
              ),
        ),
      );
      verifyNever(() => passkeys.register(any()));
      expect(await repository.hasRegisteredPasskeyOnDevice(), isFalse);
    });
  });

  group('listPasskeys', () {
    test('GET /auth/passkeys', () async {
      serve((_) async => jsonResponse(200, [passkeySummaryJson()]));

      final list = await repository.listPasskeys();

      final request = server.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/auth/passkeys');
      expect(list.single.id, FixtureIds.passkey);
      expect(list.single.isSynced, isTrue);
    });

    test('a response that is not a list shows no passkeys', () async {
      serve((_) async => jsonResponse(200, {'passkeys': []}));

      expect(await repository.listPasskeys(), isEmpty);
    });
  });

  group('deletePasskey', () {
    test(
        'DELETE /auth/passkeys/:passkeyId; deleting the last one hides the '
        'passkey button', () async {
      await storage.write(key: _passkeyFlag, value: 'true');
      serve((_) async => jsonResponse(
            200,
            securityStatusJson(hasPasskey: false),
          ));

      final status = await repository.deletePasskey(FixtureIds.passkey);

      final request = server.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/auth/passkeys/${FixtureIds.passkey}');
      expect(status.hasPasskey, isFalse);
      expect(await repository.hasRegisteredPasskeyOnDevice(), isFalse);
    });

    test('with another passkey left, the button stays', () async {
      await storage.write(key: _passkeyFlag, value: 'true');
      serve((_) async => jsonResponse(
            200,
            securityStatusJson(hasPasskey: true),
          ));

      await repository.deletePasskey(FixtureIds.passkey);

      expect(await repository.hasRegisteredPasskeyOnDevice(), isTrue);
    });

    test('the id is encoded into the path', () async {
      serve((_) async => jsonResponse(
            200,
            securityStatusJson(hasPasskey: true),
          ));

      await repository.deletePasskey('a/b c');

      expect(server.requests.single.path, '/auth/passkeys/a%2Fb%20c');
    });
  });

  group('checkUsername', () {
    test('POST /auth/check-username returns whether the name is free',
        () async {
      serve((_) async => jsonResponse(
            200,
            usernameAvailabilityJson(available: true),
          ));

      final available = await repository.checkUsername(username: 'mila');

      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/auth/check-username');
      expect(request.data, {'username': 'mila'});
      expect(available, isTrue);
    });

    test('a name the server refuses reads as not available', () async {
      for (final status in [400, 409]) {
        serve((_) async => apiErrorResponse(
              status,
              status == 400 ? 'VALIDATION_ERROR' : 'USERNAME_TAKEN',
              'How should we call you?',
            ));

        expect(await repository.checkUsername(username: ' '), isFalse);
      }
    });

    test('a server error fails instead of reading as taken', () async {
      serve((_) async => apiErrorResponse(
            500,
            'INTERNAL_ERROR',
            'Something went wrong on our end. Please try again in a bit.',
          ));

      await expectLater(
        repository.checkUsername(username: 'mila'),
        throwsA(isA<ServerError>()),
      );
    });
  });

  test('POST /auth/set-username returns the profile', () async {
    serve((_) async => jsonResponse(200, myProfileJson()));

    final profile = await repository.setUsername(username: 'mila');

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/auth/set-username');
    expect(request.data, {'username': 'mila'});
    expect(profile.id, FixtureIds.me);
    expect(profile.username, 'mila');
  });

  test('forgetRegisteredPasskey hides the button without a request', () async {
    await storage.write(key: _passkeyFlag, value: 'true');

    await repository.forgetRegisteredPasskey();

    expect(await repository.hasRegisteredPasskeyOnDevice(), isFalse);
    expect(server.requests, isEmpty);
  });
}
