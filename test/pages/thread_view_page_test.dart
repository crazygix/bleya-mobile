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

import '../fakes/fake_socket_service.dart';

class MockGetThreadUseCase extends Mock implements GetThreadUseCase {}

void main() {
  late FakeSocketService socket;
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
    socket = FakeSocketService();
    mockGetThreadUseCase = MockGetThreadUseCase();

    when(() => mockGetThreadUseCase('thread-1'))
        .thenAnswer((_) async => threadData);
  });

  testWidgets(
      'claims the room and thread while open and releases them on close',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenProvider.overrideWith((ref) => 'test-token'),
          socketServiceProvider.overrideWithValue(socket),
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

    final claim = socket.claims.single;
    expect(claim.room, room);
    expect(claim.threadId, 'thread-1');
    expect(
      socket.openChat.value,
      const OpenChat(threadId: 'thread-1'),
    );
    expect(find.text('Parent message'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(socket.claims, isEmpty);
    expect(socket.openChat.value, OpenChat.none);
    expect(socket.listenerCount('new_message'), 0);
  });
}
