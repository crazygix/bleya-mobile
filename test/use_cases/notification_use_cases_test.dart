import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bleya/use_cases/notification/get_notification_thread_context_use_case.dart';
import 'package:bleya/use_cases/notification/mark_notification_as_read_use_case.dart';
import 'package:bleya/use_cases/notification/register_push_token_use_case.dart';
import 'package:bleya/domain/entities/message.dart';
import 'package:bleya/domain/entities/room.dart';
import '../mocks.dart';

void main() {
  late MockRoomRepository mockRoomRepo;
  late MockMessageRepository mockMessageRepo;
  late MockNotificationRepository mockNotificationRepo;
  late GetNotificationThreadContextUseCase useCase;

  setUp(() {
    mockRoomRepo = MockRoomRepository();
    mockMessageRepo = MockMessageRepository();
    mockNotificationRepo = MockNotificationRepository();
    useCase = GetNotificationThreadContextUseCase(
        mockRoomRepo, mockMessageRepo);
  });

  final testRoom = Room(id: 'r1', name: 'Test Room');
  final testMessage = Message(
    id: 'm1',
    roomId: 'r1',
    userId: 'u1',
    username: 'alice',
    text: 'hello',
    createdAt: DateTime(2025, 1, 1),
  );

  test('fetches room and message in parallel and composes result', () async {
    when(() => mockRoomRepo.getRoom(any()))
        .thenAnswer((_) async => testRoom);
    when(() => mockMessageRepo.getMessage(any()))
        .thenAnswer((_) async => testMessage);

    final result = await useCase(roomId: 'r1', threadId: 'm1');

    expect(result.room, testRoom);
    expect(result.parentMessage, testMessage);
    verify(() => mockRoomRepo.getRoom('r1')).called(1);
    verify(() => mockMessageRepo.getMessage('m1')).called(1);
  });

  test('propagates room repository exception', () async {
    when(() => mockRoomRepo.getRoom(any()))
        .thenThrow(Exception('not found'));
    when(() => mockMessageRepo.getMessage(any()))
        .thenAnswer((_) async => testMessage);

    await expectLater(
      useCase(roomId: 'r1', threadId: 'm1'),
      throwsException,
    );
  });

  test('propagates message repository exception', () async {
    when(() => mockRoomRepo.getRoom(any()))
        .thenAnswer((_) async => testRoom);
    when(() => mockMessageRepo.getMessage(any()))
        .thenThrow(Exception('not found'));

    await expectLater(
      useCase(roomId: 'r1', threadId: 'm1'),
      throwsException,
    );
  });

  test('RegisterPushTokenUseCase delegates to repository.registerPushToken',
      () async {
    when(() => mockNotificationRepo.registerPushToken(
          token: any(named: 'token'),
          platform: any(named: 'platform'),
          badge: any(named: 'badge'),
        )).thenAnswer((_) async {});

    final registerUseCase = RegisterPushTokenUseCase(mockNotificationRepo);
    await registerUseCase(
      token: 'test-token',
      platform: 'ios',
    );

    verify(() => mockNotificationRepo.registerPushToken(
          token: 'test-token',
          platform: 'ios',
          badge: false,
        )).called(1);
  });

  test('RegisterPushTokenUseCase passes on that the app keeps the badge',
      () async {
    when(() => mockNotificationRepo.registerPushToken(
          token: any(named: 'token'),
          platform: any(named: 'platform'),
          badge: any(named: 'badge'),
        )).thenAnswer((_) async {});

    await RegisterPushTokenUseCase(mockNotificationRepo)(
      token: 'test-token',
      platform: 'ios',
      badge: true,
    );

    verify(() => mockNotificationRepo.registerPushToken(
          token: 'test-token',
          platform: 'ios',
          badge: true,
        )).called(1);
  });

  test('MarkNotificationAsReadUseCase delegates to repository.markAsRead',
      () async {
    when(() => mockNotificationRepo.markAsRead(any()))
        .thenAnswer((_) async {});

    final markAsReadUseCase =
        MarkNotificationAsReadUseCase(mockNotificationRepo);
    await markAsReadUseCase('notification-1');

    verify(() => mockNotificationRepo.markAsRead('notification-1')).called(1);
  });
}
