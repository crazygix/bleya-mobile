import 'dart:async';

import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/pages/dashboard_page.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/notification_provider.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks.dart';

class TestNotificationSocketListenerNotifier
    extends NotificationSocketListenerNotifier {
  @override
  Future<void> build() async {}
}

class TestNotificationNotifier extends NotificationNotifier {
  @override
  FutureOr<NotificationState> build() {
    return const NotificationState(
      notifications: [],
      unreadCount: 0,
      hasMore: false,
    );
  }
}

void main() {
  late MockRoomRepository mockRoomRepository;

  setUp(() {
    mockRoomRepository = MockRoomRepository();
  });

  ProviderScope buildApp() {
    return ProviderScope(
      overrides: [
        tokenProvider.overrideWith((ref) => 'test-token'),
        roomRepositoryProvider.overrideWithValue(mockRoomRepository),
        socketServiceProvider.overrideWithValue(SocketService()),
        notificationStateProvider.overrideWith(TestNotificationNotifier.new),
        notificationSocketListenerProvider
            .overrideWith(TestNotificationSocketListenerNotifier.new),
      ],
      child: const MaterialApp(
        home: DashboardPage(),
      ),
    );
  }

  Room room({
    required String id,
    required String name,
    String? lastMessageText,
    DateTime? lastMessageTime,
  }) {
    return Room(
      id: id,
      name: name,
      lastMessageText: lastMessageText,
      lastMessageTime: lastMessageTime,
    );
  }

  testWidgets(
      'retry button refreshes the dashboard after an initial load error',
      (tester) async {
    var callCount = 0;
    when(() => mockRoomRepository.getJoinedRooms()).thenAnswer((_) async {
      callCount += 1;
      if (callCount == 1) {
        throw Exception('network');
      }

      return [
        room(
          id: 'room-1',
          name: 'Belgrade crew',
          lastMessageText: 'See you there',
          lastMessageTime: DateTime(2026, 3, 14, 12),
        ),
      ];
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your chats"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Belgrade crew'), findsOneWidget);
    verify(() => mockRoomRepository.getJoinedRooms()).called(2);
  });

  testWidgets('pull to refresh works even when the chat list is short',
      (tester) async {
    when(() => mockRoomRepository.getJoinedRooms()).thenAnswer((_) async => [
          room(
            id: 'room-1',
            name: 'Belgrade crew',
            lastMessageText: 'See you there',
            lastMessageTime: DateTime(2026, 3, 14, 12),
          ),
        ]);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Belgrade crew'), findsOneWidget);
    verify(() => mockRoomRepository.getJoinedRooms()).called(1);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    verify(() => mockRoomRepository.getJoinedRooms()).called(1);
  });
}
