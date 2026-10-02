import 'package:bleya/data/dtos/blocked_user_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  test('parses an item of GET /users/blocked', () {
    final user = BlockedUserDto.fromJson(blockedUserJson());

    expect(user.id, FixtureIds.otherUser);
    expect(user.username, 'ana');
    expect(user.bio, '');
    expect(user.profileImageUrl, '');
    expect(
      user.blockedAt,
      DateTime.fromMillisecondsSinceEpoch(FixtureTimes.read),
    );
  });

  test('a block without a date has a null blockedAt', () {
    expect(BlockedUserDto.fromJson(blockedUserJson(blockedAt: null)).blockedAt,
        isNull);
  });

  test("missing names and bios read as ''", () {
    final user = BlockedUserDto.fromJson(
      blockedUserJson()
        ..remove('username')
        ..remove('bio'),
    );

    expect(user.username, '');
    expect(user.bio, '');
  });
}
