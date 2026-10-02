import 'package:bleya/data/repositories/room_repository_impl.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_http_adapter.dart';
import '../../fixtures/api_fixtures.dart';

void main() {
  late FakeHttpAdapter server;
  late RoomRepositoryImpl repository;

  /// Answers every request with [body].
  void respondWith(Object body, {int statusCode = 200}) {
    server = FakeHttpAdapter((_) async => jsonResponse(statusCode, body));
    repository = RoomRepositoryImpl(fakeDio(server));
  }

  /// Answers every request with the backend's error response.
  void failWith(int statusCode, String code, String message) {
    server = FakeHttpAdapter(
      (_) async => apiErrorResponse(statusCode, code, message),
    );
    repository = RoomRepositoryImpl(fakeDio(server));
  }

  group('getJoinedRooms', () {
    test('GET /rooms/joined lists the rooms in the order sent', () async {
      respondWith([joinedCityRoomJson(), joinedDirectRoomJson()]);

      final rooms = await repository.getJoinedRooms();

      final request = server.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/rooms/joined');
      expect(rooms.map((room) => room.id), [
        FixtureIds.cityRoom,
        FixtureIds.directRoom,
      ]);
      expect(rooms.first.unreadCount, 3);
      expect(rooms.last.isPrivate, isTrue);
    });

    test('fails on a response that is not a list', () async {
      respondWith({'rooms': []});

      await expectLater(repository.getJoinedRooms(), throwsException);
    });

    test('offline: fails with a network error', () async {
      server =
          FakeHttpAdapter((options) async => throw connectionError(options));
      repository = RoomRepositoryImpl(fakeDio(server));

      await expectLater(
        repository.getJoinedRooms(),
        throwsA(isA<NetworkError>()),
      );
    });
  });

  group('joinRoom', () {
    test('POST /rooms/:roomId/join returns the joined room', () async {
      respondWith(joinRoomResponseJson());

      final room = await repository.joinRoom(FixtureIds.cityRoom);

      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/rooms/${FixtureIds.cityRoom}/join');
      expect(request.data, isNull);
      expect(room.id, FixtureIds.cityRoom);
      expect(room.cityKey, FixtureIds.city);
    });

    test('fails when the response has no room', () async {
      respondWith({'message': 'Successfully joined room'});

      await expectLater(
        repository.joinRoom(FixtureIds.cityRoom),
        throwsException,
      );
    });

    test("the group chat limit fails with the server's reason", () async {
      failWith(
        400,
        'VALIDATION_ERROR',
        'You can only join up to 5 group chats at a time.',
      );

      await expectLater(
        repository.joinRoom(FixtureIds.cityRoom),
        throwsA(
          isA<BadRequestError>().having(
            (e) => e.getUserMessage(),
            'user message',
            'You can only join up to 5 group chats at a time.',
          ),
        ),
      );
    });
  });

  test('GET /rooms/:roomId/members pages with limit and offset', () async {
    respondWith([
      roomMemberJson(),
      roomMemberJson(id: FixtureIds.me, username: 'mila', bio: ''),
    ]);

    final members = await repository.getRoomMembers(
      FixtureIds.cityRoom,
      limit: 50,
      offset: 100,
    );

    final request = server.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/rooms/${FixtureIds.cityRoom}/members');
    expect(request.queryParameters, {'limit': 50, 'offset': 100});
    expect(members.map((member) => member.username), ['ana', 'mila']);
    expect(members.last.bio, '');
  });

  test('POST /rooms/:roomId/leave', () async {
    respondWith(leaveRoomJson());

    await repository.leaveRoom(FixtureIds.cityRoom);

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/rooms/${FixtureIds.cityRoom}/leave');
    expect(request.data, isNull);
  });

  group('createDirectMessage', () {
    test('POST /rooms/direct/:otherUserId returns the DM', () async {
      respondWith(openDirectRoomJson());

      final room = await repository.createDirectMessage(FixtureIds.otherUser);

      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/rooms/direct/${FixtureIds.otherUser}');
      expect(room.id, FixtureIds.directRoom);
      expect(room.isPrivate, isTrue);
      expect(room.otherUserId, FixtureIds.otherUser);
    });

    test('a blocked user fails as forbidden, with the reason', () async {
      failWith(403, 'USER_BLOCKED',
          'You blocked this user. Unblock them to message again.');

      await expectLater(
        repository.createDirectMessage(FixtureIds.otherUser),
        throwsA(
          isA<AppError>()
              .having((e) => e.code, 'code', AppErrorCode.forbidden)
              .having(
                (e) => e.getUserMessage(),
                'user message',
                'You blocked this user. Unblock them to message again.',
              ),
        ),
      );
    });
  });

  test('GET /rooms/direct/:otherUserId/status', () async {
    respondWith(directChatStatusJson(isBlockedByMe: true));

    final status = await repository.getDirectChatStatus(FixtureIds.otherUser);

    final request = server.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/rooms/direct/${FixtureIds.otherUser}/status');
    expect(status.roomId, FixtureIds.directRoom);
    expect(status.isBlockedByMe, isTrue);
    expect(status.canSendMessage, isFalse);
  });

  test('POST /rooms/direct/:otherUserId/delete', () async {
    respondWith(deleteDirectChatJson());

    final result = await repository.deleteDirectChat(FixtureIds.otherUser);

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/rooms/direct/${FixtureIds.otherUser}/delete');
    expect(result.deleted, isTrue);
    expect(result.roomId, FixtureIds.directRoom);
  });

  test('POST /rooms/direct/:otherUserId/block', () async {
    respondWith(blockDirectUserJson());

    final result = await repository.blockDirectChat(FixtureIds.otherUser);

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/rooms/direct/${FixtureIds.otherUser}/block');
    expect(result.blocked, isTrue);
    expect(result.message, 'User blocked.');
  });

  test('POST /rooms/direct/:otherUserId/unblock', () async {
    respondWith(unblockDirectUserJson());

    final result = await repository.unblockDirectChat(FixtureIds.otherUser);

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/rooms/direct/${FixtureIds.otherUser}/unblock');
    expect(result.blocked, isFalse);
    expect(result.message, 'User unblocked.');
  });

  group('getRoom', () {
    test('GET /rooms/:roomId', () async {
      respondWith(roomDetailJson());

      final room = await repository.getRoom(FixtureIds.cityRoom);

      final request = server.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/rooms/${FixtureIds.cityRoom}');
      expect(room.name, 'Belgrade, Serbia');
      expect(room.hasUnreadCount, isFalse);
    });

    test('a room the user left fails as forbidden', () async {
      failWith(403, 'FORBIDDEN', 'You are not a member of this room.');

      await expectLater(
        repository.getRoom(FixtureIds.cityRoom),
        throwsA(
          isA<AppError>()
              .having((e) => e.code, 'code', AppErrorCode.forbidden)
              .having((e) => e.originalError, 'cause', isA<DioException>()),
        ),
      );
    });
  });
}
