import 'package:bleya/domain/entities/message.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/domain/repositories/message_repository.dart';
import 'package:bleya/pages/thread_view_page.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/use_case_providers.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:bleya/use_cases/message/get_thread_use_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSocketService extends Mock implements SocketService {}

class MockGetThreadUseCase extends Mock implements GetThreadUseCase {}

void main() {
  late MockSocketService mockSocketService;
  late MockGetThreadUseCase mockGetThreadUseCase;

  final room = Room(
    id: 'room-1',
    name: 'General',
  );
  final parentMessage = Message(
    id: 'thread-1',
    roomId: 'room-1',
    userId: 'user-1',
    username: 'alice',
    text: 'Parent message',
    createdAt: DateTime(2026, 1, 1),
  );
  final threadData = ThreadData(
    parentMessage: parentMessage,
    replies: const [],
  );

  setUp(() {
    mockSocketService = MockSocketService();
    mockGetThreadUseCase = MockGetThreadUseCase();

    when(() => mockSocketService.joinRoom(room)).thenAnswer((_) async {});
    when(() => mockSocketService.openThread(any())).thenReturn(null);
    when(() => mockSocketService.closeThread()).thenReturn(null);
    when(() => mockSocketService.addListener(any(), any()))
        .thenReturn(Object());
    when(() => mockSocketService.removeListener(any(), any())).thenReturn(null);
    when(() => mockGetThreadUseCase('thread-1'))
        .thenAnswer((_) async => threadData);
  });

  testWidgets('opens and closes thread presence with socket service',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenProvider.overrideWith((ref) => 'test-token'),
          socketServiceProvider.overrideWithValue(mockSocketService),
          getThreadUseCaseProvider.overrideWithValue(mockGetThreadUseCase),
        ],
        child: MaterialApp(
          home: ThreadViewPage(
            parentMessage: parentMessage,
            room: room,
          ),
        ),
      ),
    );
    await tester.pump();

    verify(() => mockSocketService.joinRoom(room)).called(1);
    verify(() => mockSocketService.openThread('thread-1')).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    verify(() => mockSocketService.closeThread()).called(1);
  });
}
