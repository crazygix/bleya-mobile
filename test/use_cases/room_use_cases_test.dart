import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bleya/use_cases/room/join_room_use_case.dart';
import 'package:bleya/use_cases/room/get_joined_rooms_use_case.dart';
import 'package:bleya/use_cases/room/leave_room_use_case.dart';
import 'package:bleya/use_cases/room/create_direct_message_use_case.dart';
import 'package:bleya/use_cases/room/get_room_members_use_case.dart';
import 'package:bleya/use_cases/room/get_room_use_case.dart';
import 'package:bleya/use_cases/room/get_direct_chat_status_use_case.dart';
import 'package:bleya/use_cases/room/delete_direct_chat_use_case.dart';
import 'package:bleya/use_cases/room/block_direct_chat_use_case.dart';
import 'package:bleya/use_cases/room/unblock_direct_chat_use_case.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/domain/entities/room_member.dart';
import 'package:bleya/domain/entities/direct_chat_status.dart';
import '../mocks.dart';

void main() {
  late MockRoomRepository mockRepo;

  setUp(() {
    mockRepo = MockRoomRepository();
  });

  final testRoom = Room(id: 'room1', name: 'Test Room');

  group('JoinRoomUseCase', () {
    test('delegates to repository.joinRoom', () async {
      when(() => mockRepo.joinRoom(any())).thenAnswer((_) async => testRoom);
      final useCase = JoinRoomUseCase(mockRepo);

      final result = await useCase('room1');

      expect(result, testRoom);
      verify(() => mockRepo.joinRoom('room1')).called(1);
    });
  });

  group('GetJoinedRoomsUseCase', () {
    test('delegates to repository.getJoinedRooms', () async {
      when(() => mockRepo.getJoinedRooms())
          .thenAnswer((_) async => [testRoom]);
      final useCase = GetJoinedRoomsUseCase(mockRepo);

      final result = await useCase();

      expect(result, [testRoom]);
      verify(() => mockRepo.getJoinedRooms()).called(1);
    });
  });

  group('GetRoomUseCase', () {
    test('delegates to repository.getRoom', () async {
      when(() => mockRepo.getRoom(any())).thenAnswer((_) async => testRoom);
      final useCase = GetRoomUseCase(mockRepo);

      final result = await useCase('room1');

      expect(result, testRoom);
      verify(() => mockRepo.getRoom('room1')).called(1);
    });
  });

  group('LeaveRoomUseCase', () {
    test('delegates to repository.leaveRoom', () async {
      when(() => mockRepo.leaveRoom(any())).thenAnswer((_) async {});
      final useCase = LeaveRoomUseCase(mockRepo);

      await useCase('room1');

      verify(() => mockRepo.leaveRoom('room1')).called(1);
    });
  });

  group('CreateDirectMessageUseCase', () {
    test('delegates to repository.createDirectMessage', () async {
      when(() => mockRepo.createDirectMessage(any()))
          .thenAnswer((_) async => testRoom);
      final useCase = CreateDirectMessageUseCase(mockRepo);

      final result = await useCase('user2');

      expect(result, testRoom);
      verify(() => mockRepo.createDirectMessage('user2')).called(1);
    });
  });

  group('GetRoomMembersUseCase', () {
    test('delegates one page to repository.getRoomMembers', () async {
      final members = [
        RoomMember(
            id: 'u1', username: 'alice', bio: '', profileImageUrl: ''),
      ];
      when(() => mockRepo.getRoomMembers(
            any(),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => members);
      final useCase = GetRoomMembersUseCase(mockRepo);

      final result = await useCase('room1', limit: 100, offset: 200);

      expect(result, members);
      verify(() => mockRepo.getRoomMembers('room1', limit: 100, offset: 200))
          .called(1);
    });

    test('starts at the first member by default', () async {
      when(() => mockRepo.getRoomMembers(
            any(),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);
      final useCase = GetRoomMembersUseCase(mockRepo);

      await useCase('room1', limit: 100);

      verify(() => mockRepo.getRoomMembers('room1', limit: 100, offset: 0))
          .called(1);
    });
  });

  group('GetDirectChatStatusUseCase', () {
    test('delegates to repository.getDirectChatStatus', () async {
      const status = DirectChatStatus(
        hasChat: true,
        roomId: 'r1',
        isBlockedByMe: false,
        isBlockedByOtherUser: false,
        canSendMessage: true,
        isDeletedByMe: false,
      );
      when(() => mockRepo.getDirectChatStatus(any()))
          .thenAnswer((_) async => status);
      final useCase = GetDirectChatStatusUseCase(mockRepo);

      final result = await useCase('user2');

      expect(result, status);
      verify(() => mockRepo.getDirectChatStatus('user2')).called(1);
    });
  });

  group('DeleteDirectChatUseCase', () {
    test('delegates to repository.deleteDirectChat', () async {
      const expected = DirectChatActionResult(
        message: 'deleted',
        roomId: 'r1',
        hasChat: false,
        blocked: false,
        deleted: true,
        alreadyBlocked: false,
      );
      when(() => mockRepo.deleteDirectChat(any()))
          .thenAnswer((_) async => expected);
      final useCase = DeleteDirectChatUseCase(mockRepo);

      final result = await useCase('user2');

      expect(result, expected);
      verify(() => mockRepo.deleteDirectChat('user2')).called(1);
    });
  });

  group('BlockDirectChatUseCase', () {
    test('delegates to repository.blockDirectChat', () async {
      const expected = DirectChatActionResult(
        message: 'blocked',
        roomId: 'r1',
        hasChat: true,
        blocked: true,
        deleted: false,
        alreadyBlocked: false,
      );
      when(() => mockRepo.blockDirectChat(any()))
          .thenAnswer((_) async => expected);
      final useCase = BlockDirectChatUseCase(mockRepo);

      final result = await useCase('user2');

      expect(result, expected);
      verify(() => mockRepo.blockDirectChat('user2')).called(1);
    });
  });

  group('UnblockDirectChatUseCase', () {
    test('delegates to repository.unblockDirectChat', () async {
      const expected = DirectChatActionResult(
        message: 'unblocked',
        roomId: 'r1',
        hasChat: true,
        blocked: false,
        deleted: false,
        alreadyBlocked: false,
      );
      when(() => mockRepo.unblockDirectChat(any()))
          .thenAnswer((_) async => expected);
      final useCase = UnblockDirectChatUseCase(mockRepo);

      final result = await useCase('user2');

      expect(result, expected);
      verify(() => mockRepo.unblockDirectChat('user2')).called(1);
    });
  });
}
