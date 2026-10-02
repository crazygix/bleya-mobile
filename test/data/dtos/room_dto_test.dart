import 'package:bleya/data/dtos/room_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  group('GET /rooms/joined', () {
    test('parses a city room with its preview and unread count', () {
      final room = RoomDto.fromJson(joinedCityRoomJson());

      expect(room.id, FixtureIds.cityRoom);
      expect(room.name, 'Belgrade, Serbia');
      expect(room.type, 'public');
      expect(room.isPrivate, isFalse);
      expect(room.cityKey, FixtureIds.city);
      expect(room.participants, isEmpty);
      expect(room.otherUserId, isNull);
      expect(room.imageUrl, 'https://cdn.example.com/cities/belgrade-rs.webp');
      expect(room.location?.latitude, 44.80401);
      expect(room.location?.longitude, 20.46513);
      expect(room.lastMessageText, 'Anyone up for coffee near Knez Mihailova?');
      expect(
        room.lastMessageTime,
        DateTime.fromMillisecondsSinceEpoch(FixtureTimes.sent),
      );
      expect(room.lastMessageUserId, FixtureIds.otherUser);
      expect(room.lastMessageUsername, 'ana');
      expect(room.unreadCount, 3);
      expect(room.hasUnreadCount, isTrue);
    });

    test('parses a DM without messages', () {
      final room = RoomDto.fromJson(joinedDirectRoomJson());

      expect(room.type, 'private');
      expect(room.isPrivate, isTrue);
      expect(room.name, 'ana');
      expect(room.participants, [FixtureIds.me, FixtureIds.otherUser]);
      expect(room.otherUserId, FixtureIds.otherUser);
      expect(room.imageUrl, isNull);
      expect(room.cityKey, isNull);
      expect(room.location, isNull);
      expect(room.lastMessageText, isNull);
      expect(room.lastMessageTime, isNull);
      expect(room.lastMessageUsername, isNull);
      expect(room.unreadCount, 0);
      expect(room.hasUnreadCount, isTrue);
    });

    test('reads unread counts that are not whole, positive numbers', () {
      int unreadOf(Object value) =>
          RoomDto.fromJson(joinedCityRoomJson()..['unreadCount'] = value)
              .unreadCount;

      expect(unreadOf(-2), 0);
      expect(unreadOf(2.6), 3);
      expect(unreadOf('4'), 4);
      expect(unreadOf('many'), 0);
    });

    test('drops a location without both coordinates', () {
      final json = joinedCityRoomJson()..['location'] = {'latitude': 44.80401};

      expect(RoomDto.fromJson(json).location, isNull);
    });
  });

  test('GET /rooms/:roomId has no unread count to show', () {
    final room = RoomDto.fromJson(roomDetailJson());

    expect(room.id, FixtureIds.cityRoom);
    expect(room.cityKey, FixtureIds.city);
    expect(room.location, isNotNull);
    expect(room.unreadCount, 0);
    expect(room.hasUnreadCount, isFalse);
  });

  test('POST /rooms/:roomId/join returns the room summary', () {
    final room = RoomDto.fromJson(
      joinRoomResponseJson()['room'] as Map<String, dynamic>,
    );

    expect(room.id, FixtureIds.cityRoom);
    expect(room.type, 'public');
    expect(room.location?.longitude, 20.46513);
    expect(room.lastMessageTime, isNull);
    expect(room.isJoined, isFalse);
  });

  test('POST /cities/:cityId/join: a room without type or location', () {
    final room = RoomDto.fromJson(
      joinCityJson()['room'] as Map<String, dynamic>,
    );

    expect(room.id, FixtureIds.cityRoom);
    expect(room.name, 'Belgrade, Serbia');
    expect(room.type, 'public');
    expect(room.cityKey, FixtureIds.city);
    expect(room.location, isNull);
    expect(room.participants, isEmpty);
    expect(room.isJoined, isFalse);
  });

  test('POST /rooms/direct/:otherUserId returns the DM', () {
    final room = RoomDto.fromJson(
      openDirectRoomJson()['room'] as Map<String, dynamic>,
    );

    expect(room.id, FixtureIds.directRoom);
    expect(room.isPrivate, isTrue);
    expect(room.name, 'ana');
    expect(room.otherUserId, FixtureIds.otherUser);
    expect(room.imageUrl, startsWith('https://cdn.example.com/profiles/'));
  });
}
