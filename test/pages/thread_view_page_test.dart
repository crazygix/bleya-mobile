import 'dart:convert';

import 'package:bleya/domain/entities/message.dart';
import 'package:bleya/domain/entities/report_reason.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/domain/repositories/message_repository.dart';
import 'package:bleya/domain/repositories/notification_repository.dart';
import 'package:bleya/pages/thread_view_page.dart';
import 'package:bleya/platform/app_route.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/chat_room_providers.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:bleya/providers/use_case_providers.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:bleya/use_cases/message/get_thread_use_case.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:bleya/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_socket_service.dart';
import '../mocks.dart';

class MockGetThreadUseCase extends Mock implements GetThreadUseCase {}

/// An access token for the signed-in user, `user-me`.
final _myToken = () {
  String encode(Map<String, Object> part) =>
      base64Url.encode(utf8.encode(jsonEncode(part))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode({'userId': 'user-me'})}.sig';
}();

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

  Message reply(String id, String userId, String text) {
    return Message(
      id: id,
      roomId: 'room-1',
      userId: userId,
      username: userId.replaceFirst('user-', ''),
      text: text,
      createdAt: DateTime(2026, 1, 1, 10),
      parentMessageId: 'thread-1',
    );
  }

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

  group('message actions', () {
    late MockUserRepository users;
    late MockReportRepository reports;
    late MockRoomRepository rooms;
    late MockNotificationRepository notifications;
    late ProviderContainer container;

    setUpAll(() {
      registerFallbackValue(ReportReason.other);
    });

    setUp(() {
      users = MockUserRepository();
      reports = MockReportRepository();
      rooms = MockRoomRepository();
      notifications = MockNotificationRepository();
      when(() => users.blockUser(any())).thenAnswer((_) async {});
      when(
        () => reports.createReport(
          reportedUserId: any(named: 'reportedUserId'),
          roomId: any(named: 'roomId'),
          messageId: any(named: 'messageId'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
        ),
      ).thenAnswer((_) async {});
      when(() => rooms.getJoinedRooms()).thenAnswer((_) async => []);
      when(
        () => notifications.fetchNotifications(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => const NotificationPage(notifications: [], unreadCount: 0),
      );
      when(() => mockGetThreadUseCase('thread-1')).thenAnswer(
        (_) async => ThreadData(
          parentMessage: parentMessage,
          replies: [
            reply('reply-1', 'user-bob', 'Count me in'),
            reply('reply-2', 'user-1', 'Bring snacks'),
            reply('reply-3', 'user-me', 'On my way'),
          ],
        ),
      );
      container = ProviderContainer(
        overrides: [
          tokenProvider.overrideWith((ref) => _myToken),
          socketServiceProvider.overrideWithValue(socket),
          getThreadUseCaseProvider.overrideWithValue(mockGetThreadUseCase),
          userRepositoryProvider.overrideWithValue(users),
          reportRepositoryProvider.overrideWithValue(reports),
          roomRepositoryProvider.overrideWithValue(rooms),
          notificationRepositoryProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);
    });

    /// Opens the thread over a room screen, as tapping a message does, on a
    /// tall phone, where the report sheet fits.
    Future<void> openThread(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1290, 2796)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            navigatorObservers: [appRouteObserver],
            home: const Scaffold(body: Text('Room')),
          ),
        ),
      );
      navigatorKey.currentState!.push(
        AppRoute.build(
          builder: (_) =>
              ThreadViewPage(parentMessage: parentMessage, room: room),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Closes the thread and lets its toasts finish.
    Future<void> closeThread(WidgetTester tester) async {
      navigatorKey.currentState!.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
    }

    testWidgets("long-pressing someone else's reply offers report and block",
        (tester) async {
      await openThread(tester);

      await tester.longPress(find.text('Count me in'));
      await tester.pumpAndSettle();

      expect(find.text('Report message'), findsOneWidget);
      expect(find.text('Block author'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await closeThread(tester);
    });

    testWidgets('your own reply has no actions', (tester) async {
      await openThread(tester);

      await tester.longPress(find.text('On my way'));
      await tester.pumpAndSettle();

      expect(find.text('Report message'), findsNothing);
      await closeThread(tester);
    });

    testWidgets('reporting a reply sends that reply and its author',
        (tester) async {
      await openThread(tester);

      await tester.longPress(find.text('Count me in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Harassment or bullying'));
      await tester.pumpAndSettle();

      verify(
        () => reports.createReport(
          reportedUserId: 'user-bob',
          messageId: 'reply-1',
          reason: ReportReason.harassment,
        ),
      ).called(1);
      expect(find.text("Thanks for the report. We'll take a look."),
          findsOneWidget);
      await closeThread(tester);
    });

    testWidgets(
        "blocking the first message's author keeps the thread open and hides "
        'their replies', (tester) async {
      await openThread(tester);

      await tester.longPress(find.text('Parent message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block author'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      verify(() => users.blockUser('user-1')).called(1);
      expect(container.read(sessionBlockedUserIdsProvider), {'user-1'});
      expect(find.text('User blocked.'), findsOneWidget);

      // Still the thread, with its first message, until the user leaves.
      expect(find.byType(ThreadViewPage), findsOneWidget);
      expect(find.text('Parent message'), findsOneWidget);
      expect(find.text('Bring snacks'), findsNothing);
      expect(find.text('Count me in'), findsOneWidget);
      expect(find.text('On my way'), findsOneWidget);
      await closeThread(tester);
    });

    testWidgets('a failed block says why and hides nothing', (tester) async {
      when(() => users.blockUser(any())).thenThrow(
        NetworkError(
          message: 'Network connection error',
          userMessage: 'Unable to connect to the server. Please check your '
              'internet connection.',
        ),
      );
      await openThread(tester);

      await tester.longPress(find.text('Count me in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block author'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to connect to the server. Please check your '
            'internet connection.'),
        findsOneWidget,
      );
      expect(container.read(sessionBlockedUserIdsProvider), isEmpty);
      expect(find.text('Count me in'), findsOneWidget);
      await closeThread(tester);
    });
  });

  group('a thread that does not load', () {
    Future<void> showThread(WidgetTester tester, Object error) async {
      when(() => mockGetThreadUseCase('thread-1')).thenThrow(error);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenProvider.overrideWith((ref) => 'test-token'),
            socketServiceProvider.overrideWithValue(socket),
            getThreadUseCaseProvider.overrideWithValue(mockGetThreadUseCase),
          ],
          child: MaterialApp(
            home: ThreadViewPage(parentMessage: parentMessage, room: room),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('says the message is no longer available when it is gone',
        (tester) async {
      await showThread(
        tester,
        NotFoundError(
          message: 'Message not found',
          userMessage: 'Message not found',
        ),
      );

      expect(find.text('This message is no longer available.'), findsOneWidget);
      expect(find.text('Message not found'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets("shows a connection problem in the user's words",
        (tester) async {
      await showThread(
          tester, NetworkError(message: 'Network connection error'));

      expect(
        find.text('Connection issue. Check your internet and try again?'),
        findsOneWidget,
      );
      expect(find.textContaining('Network connection error'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('never shows raw error text', (tester) async {
      await showThread(tester, StateError('Bad state: no element'));

      expect(find.text('Something went wrong. Try again?'), findsOneWidget);
      expect(find.textContaining('Bad state'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
