import 'package:bleya/data/dtos/user_profile_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  test('parses GET /users/me', () {
    final profile = UserProfileDto.fromJson(myProfileJson());

    expect(profile.id, FixtureIds.me);
    expect(profile.username, 'mila');
    expect(
      profile.createdAt,
      DateTime.fromMillisecondsSinceEpoch(FixtureTimes.accountCreated),
    );
    expect(
      profile.lastLogin,
      DateTime.fromMillisecondsSinceEpoch(FixtureTimes.lastLogin),
    );
  });

  test("keeps the server's '' for an empty bio and no photo", () {
    final profile = UserProfileDto.fromJson(myProfileJson());

    expect(profile.bio, '');
    expect(profile.profileImageUrl, '');
  });

  test('a public profile has no last sign-in', () {
    final profile = UserProfileDto.fromJson(publicProfileJson());

    expect(profile.id, FixtureIds.otherUser);
    expect(profile.bio, 'Coffee, trams and long walks.');
    expect(profile.profileImageUrl, startsWith('https://cdn.example.com/'));
    expect(profile.lastLogin, isNull);
  });

  test('takes the id from id, then userId, then _id', () {
    Map<String, dynamic> withoutId() => myProfileJson()..remove('id');

    expect(
      UserProfileDto.fromJson(withoutId()..['userId'] = 'from-user-id').id,
      'from-user-id',
    );
    expect(
      UserProfileDto.fromJson(withoutId()..['_id'] = 'from-underscore-id').id,
      'from-underscore-id',
    );
    expect(UserProfileDto.fromJson(withoutId()).id, '');
  });
}
