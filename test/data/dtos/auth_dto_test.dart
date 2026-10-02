import 'package:bleya/data/dtos/auth_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  group('authSessionResultFromJson', () {
    test('parses a sign-in to an account with a passkey', () {
      final result = authSessionResultFromJson(authSessionJson(
        hasPasskey: true,
      ));

      expect(result.token, 'access-token-1');
      expect(result.requiresUsername, isFalse);
      expect(result.hasPasskey, isTrue);
    });

    test('parses a new account that still needs a username', () {
      final result = authSessionResultFromJson(authSessionJson(
        requiresUsername: true,
      ));

      expect(result.requiresUsername, isTrue);
      expect(result.hasPasskey, isFalse);
    });

    test('missing fields give no token and no flags', () {
      final result = authSessionResultFromJson(<String, dynamic>{});

      expect(result.token, '');
      expect(result.requiresUsername, isFalse);
      expect(result.hasPasskey, isFalse);
    });
  });

  test('authSecurityStatusFromJson reads hasPasskey, false when missing', () {
    expect(
      authSecurityStatusFromJson(securityStatusJson(hasPasskey: true))
          .hasPasskey,
      isTrue,
    );
    expect(
      authSecurityStatusFromJson(securityStatusJson(hasPasskey: false))
          .hasPasskey,
      isFalse,
    );
    expect(authSecurityStatusFromJson(<String, dynamic>{}).hasPasskey, isFalse);
  });

  test('parses a passkey summary from GET /auth/passkeys', () {
    final passkey = passkeySummaryFromJson(passkeySummaryJson());

    expect(passkey.id, FixtureIds.passkey);
    expect(passkey.isSynced, isTrue);
    expect(
      passkey.createdAt,
      DateTime.fromMillisecondsSinceEpoch(FixtureTimes.lastLogin),
    );
    expect(passkey.lastUsedAt, isNull);
  });

  test('a passkey that was used has a lastUsedAt', () {
    final passkey = passkeySummaryFromJson(
      passkeySummaryJson(lastUsedAt: FixtureTimes.read),
    );

    expect(
      passkey.lastUsedAt,
      DateTime.fromMillisecondsSinceEpoch(FixtureTimes.read),
    );
  });

  test('a single-device passkey that is not backed up is not synced', () {
    final passkey = passkeySummaryFromJson({
      'id': 'p2',
      'deviceType': 'singleDevice',
      'backedUp': false,
    });

    expect(passkey.isSynced, isFalse);
    expect(passkey.createdAt, isNull);
  });
}
