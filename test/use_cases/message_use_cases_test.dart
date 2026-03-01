import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bleya/use_cases/message/get_thread_use_case.dart';
import 'package:bleya/use_cases/message/get_room_messages_page_use_case.dart';
import 'package:bleya/domain/entities/message.dart';
import 'package:bleya/domain/repositories/message_repository.dart';
import '../mocks.dart';

void main() {
  late MockMessageRepository mockRepo;

  setUp(() {
    mockRepo = MockMessageRepository();
  });

  final testMessage = Message(
    id: 'm1',
    roomId: 'r1',
    userId: 'u1',
    username: 'alice',
    text: 'hello',
    createdAt: DateTime(2025, 1, 1),
  );

  group('GetThreadUseCase', () {
    test('delegates to repository.getThread', () async {
      final threadData = ThreadData(parentMessage: testMessage, replies: []);
      when(() => mockRepo.getThread(any()))
          .thenAnswer((_) async => threadData);
      final useCase = GetThreadUseCase(mockRepo);

      final result = await useCase('m1');

      expect(result, threadData);
      verify(() => mockRepo.getThread('m1')).called(1);
    });
  });

  group('GetRoomMessagesPageUseCase', () {
    test('delegates to repository.getRoomMessagesPage', () async {
      final page = RoomMessagesPage(
        messages: [testMessage],
        hasMore: false,
        nextCursor: null,
      );
      when(() => mockRepo.getRoomMessagesPage(
            any(),
            before: any(named: 'before'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => page);
      final useCase = GetRoomMessagesPageUseCase(mockRepo);

      final result = await useCase('r1', before: 'cursor', limit: 20);

      expect(result, page);
      verify(() =>
              mockRepo.getRoomMessagesPage('r1', before: 'cursor', limit: 20))
          .called(1);
    });
  });

  group('MarkRoomAsReadUseCase', () {
    test('delegates to repository.markRoomAsRead', () async {
      when(() => mockRepo.markRoomAsRead(any()))
          .thenAnswer((_) async => 1234567890);
      final useCase = MarkRoomAsReadUseCase(mockRepo);

      final result = await useCase('r1');

      expect(result, 1234567890);
      verify(() => mockRepo.markRoomAsRead('r1')).called(1);
    });
  });
}
