import 'package:bleya/services/passkey_auth_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:passkeys/types.dart';

import '../mocks.dart';

/// The Android security error behind a build that isn't trusted for the
/// passkey domain, as passkeys_android names it for [operation].
String _securityError(String operation) {
  return 'android-unhandled: androidx.credentials.TYPE_${operation}_DOM_EXCEPTION/'
      'androidx.credentials.TYPE_SECURITY_ERROR';
}

const _registerOptions = PasskeyRequestOptions(
  challengeId: 'challenge-1',
  payload: {
    'challenge': 'dGVzdC1jaGFsbGVuZ2U',
    'rp': {'id': 'bleyachat.com', 'name': 'Bleya'},
    'user': {'id': 'dXNlci0x', 'name': 'ana', 'displayName': 'ana'},
  },
);

const _authenticateOptions = PasskeyRequestOptions(
  challengeId: 'challenge-2',
  payload: {'challenge': 'dGVzdC1jaGFsbGVuZ2U', 'rpId': 'bleyachat.com'},
);

void main() {
  late MockPasskeyAuthenticator authenticator;
  late PasskeyAuthService service;

  setUpAll(() {
    registerFallbackValue(
      RegisterRequestType.fromJson(_registerOptions.payload),
    );
    registerFallbackValue(
      AuthenticateRequestType.fromJson(_authenticateOptions.payload),
    );
  });

  setUp(() {
    authenticator = MockPasskeyAuthenticator();
    service = PasskeyAuthService(authenticator: authenticator);
  });

  void failRegister(Object error) {
    when(() => authenticator.register(any())).thenThrow(error);
  }

  void failAuthenticate(Object error) {
    when(() => authenticator.authenticate(any())).thenThrow(error);
  }

  group('register', () {
    test('an untrusted Android build fails as on iOS: domain not associated',
        () async {
      failRegister(PlatformException(
        code: _securityError('CREATE_PUBLIC_KEY_CREDENTIAL'),
        message: 'The incoming request cannot be validated',
      ));

      await expectLater(
        service.register(_registerOptions),
        throwsA(isA<DomainNotAssociatedException>().having(
          (e) => e.message,
          'message',
          'The incoming request cannot be validated',
        )),
      );
    });

    test('no passkey provider fails as no create option', () async {
      failRegister(PlatformException(code: 'android-no-create-option'));

      await expectLater(
        service.register(_registerOptions),
        throwsA(isA<NoCreateOptionException>()),
      );
    });

    test('an iOS error passes through unchanged', () async {
      final error = PlatformException(code: 'ios-unhandled-WKErrorDomain');
      failRegister(error);

      await expectLater(
        service.register(_registerOptions),
        throwsA(same(error)),
      );
    });

    test('a cancel passes through unchanged', () async {
      final error = PasskeyAuthCancelledException();
      failRegister(error);

      await expectLater(
        service.register(_registerOptions),
        throwsA(same(error)),
      );
    });
  });

  group('authenticate', () {
    test('an untrusted Android build fails as on iOS: domain not associated',
        () async {
      failAuthenticate(UnhandledAuthenticatorException(
        _securityError('GET_PUBLIC_KEY_CREDENTIAL'),
        'The incoming request cannot be validated',
        null,
      ));

      await expectLater(
        service.authenticate(_authenticateOptions),
        throwsA(isA<DomainNotAssociatedException>()),
      );
    });

    test('an unavailable sync account fails as such', () async {
      failAuthenticate(
        PlatformException(code: 'android-sync-account-not-available'),
      );

      await expectLater(
        service.authenticate(_authenticateOptions),
        throwsA(isA<SyncAccountNotAvailableException>()),
      );
    });

    test('other unhandled errors pass through unchanged', () async {
      final error = UnhandledAuthenticatorException(
        'android-unhandled: androidx.credentials.TYPE_UNKNOWN',
        'Something internal',
        null,
      );
      failAuthenticate(error);

      await expectLater(
        service.authenticate(_authenticateOptions),
        throwsA(same(error)),
      );
    });

    test('returns the response when it succeeds', () async {
      when(() => authenticator.authenticate(any())).thenAnswer(
        (_) async => AuthenticateResponseType(
          id: 'credential-1',
          rawId: 'credential-1',
          clientDataJSON: 'client-data',
          authenticatorData: 'authenticator-data',
          signature: 'signature',
          userHandle: 'dXNlci0x',
        ),
      );

      final response = await service.authenticate(_authenticateOptions);

      expect(response['id'], 'credential-1');
    });
  });
}
