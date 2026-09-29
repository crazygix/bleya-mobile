import 'package:bleya/data/dtos/auth_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a passkey summary from GET /auth/passkeys', () {
    final passkey = passkeySummaryFromJson({
      'id': 'p1',
      'deviceType': 'multiDevice',
      'backedUp': true,
      'createdAt': 1767225600000,
      'lastUsedAt': null,
    });

    expect(passkey.id, 'p1');
    expect(passkey.isSynced, isTrue);
    expect(
        passkey.createdAt, DateTime.fromMillisecondsSinceEpoch(1767225600000));
    expect(passkey.lastUsedAt, isNull);
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
