import 'package:bleya/data/dtos/room_member_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  test('parses an item of GET /rooms/:roomId/members', () {
    final member = RoomMemberDto.fromJson(roomMemberJson());

    expect(member.id, FixtureIds.otherUser);
    expect(member.username, 'ana');
    expect(member.bio, 'Coffee, trams and long walks.');
    expect(member.profileImageUrl, startsWith('https://cdn.example.com/'));
  });

  test("missing fields read as ''", () {
    final member = RoomMemberDto.fromJson(<String, dynamic>{});

    expect(member.id, '');
    expect(member.username, '');
    expect(member.bio, '');
    expect(member.profileImageUrl, '');
  });
}
