import 'dart:async';

import 'package:bleya/domain/entities/message.dart';
import 'package:bleya/domain/entities/notification.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/domain/repositories/message_repository.dart';
import 'package:bleya/domain/repositories/notification_repository.dart';
import 'package:bleya/pages/notifications_page.dart';
import 'package:bleya/pages/thread_view_page.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/notification_provider.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:bleya/providers/use_case_providers.dart';
import 'package:bleya/use_cases/notification/get_notification_thread_context_use_case.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:bleya/utils/navigation.dart';
import 'package:bleya/widgets/app_spinner.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_socket_service.dart';
import '../mocks.dart';

final _room = Room(id: 'room-1', name: 'Belgrade');
final _parent = Message(
  id: 'thread-1',
  roomId: 'room-1',
  userId: 'user-ana',
  username: 'ana',
  text: 'Coffee at noon?',
  createdAt: DateTime(2026, 10, 1, 9),
);

Notification _reply(String id, String text) {
  return Notification(
    id: id,
    senderId: 'user-bob',
    senderName: 'bob',
    roomId: 'room-1',
    roomName: 'Belgrade',
    roomType: 'public',
    messageId: 'reply-$id',
    threadId: 'thread-1',
    replyText: text,
    previewText: text,
    type: 'reply',
    isRead: false,
    createdAt: DateTime(2026, 10, 1, 10),
  );
}

/// Answers the thread request when the test says so.
class _ThreadContextLoader extends Fake
    implements GetNotificationThreadContextUseCase {
  // Made by the request, in the test's zone, so its answer arrives on pump.
  Completer<NotificationThreadContext>? _answer;

  @override
  Future<NotificationThreadContext> call({
    required String roomId,
    required String threadId,
  }) {
    return (_answer = Completer<NotificationThreadContext>()).future;
  }

  void load() {
    _answer!.complete(
      NotificationThreadContext(room: _room, parentMessage: _parent),
    );
  }

  void fail(Object error) => _answer!.completeError(error);
}

void main() {
  late MockNotificationRepository notifications;
  late MockMessageRepository messages;
  late _ThreadContextLoader threadContext;
  late ProviderContainer container;

  setUp(() {
    notifications = MockNotificationRepository();
    messages = MockMessageRepository();
    threadContext = _ThreadContextLoader();
    when(() => notifications.dismissNotification(any()))
        .thenAnswer((_) async {});
    when(() => notifications.markAllAsRead()).thenAnswer((_) async {});
    when(() => messages.getThread('thread-1')).thenAnswer(
      (_) async => ThreadData(parentMessage: _parent, replies: const []),
    );
    container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => 'test-token'),
        socketServiceProvider.overrideWithValue(FakeSocketService()),
        notificationRepositoryProvider.overrideWithValue(notifications),
        messageRepositoryProvider.overrideWithValue(messages),
        getNotificationThreadContextUseCaseProvider
            .overrideWithValue(threadContext),
      ],
    );
    addTearDown(container.dispose);
  });

  NavigatorState navigator() => navigatorKey.currentState!;

  /// Shows Activity with [items], as the dashboard's Activity tab does.
  Future<void> showActivity(
    WidgetTester tester,
    List<Notification> items,
  ) async {
    when(
      () => notifications.fetchNotifications(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer(
      (_) async => NotificationPage(
        notifications: items,
        unreadCount: items.length,
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [appRouteObserver],
          home: const Scaffold(body: NotificationsPage()),
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets a route transition finish.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Back to Activity, past any toast, so nothing is left running.
  Future<void> finish(WidgetTester tester) async {
    navigator().popUntil((route) => route.isFirst);
    await settle(tester);
    await tester.pump(const Duration(seconds: 4));
  }

  bool loaderShows() => find.byType(AppSpinner).evaluate().isNotEmpty;

  List<String> listedIds() => container
      .read(notificationStateProvider)
      .requireValue
      .notifications
      .map((n) => n.id)
      .toList();

  testWidgets('tapping the only item opens its thread, then dismisses it',
      (tester) async {
    await showActivity(tester, [_reply('n1', 'See you there')]);

    await tester.tap(find.text('See you there'));
    await tester.pump();
    expect(loaderShows(), isTrue);
    // Still listed while its thread loads.
    expect(find.text('See you there'), findsOneWidget);

    threadContext.load();
    await settle(tester);

    expect(find.byType(ThreadViewPage), findsOneWidget);
    expect(find.text('Coffee at noon?'), findsOneWidget);
    expect(loaderShows(), isFalse);
    verify(() => notifications.dismissNotification('n1')).called(1);

    navigator().pop();
    await settle(tester);

    expect(find.text('Nothing new here'), findsOneWidget);
    expect(navigator().canPop(), isFalse);
    await finish(tester);
  });

  testWidgets('back during loading cancels: Activity stays and keeps the item',
      (tester) async {
    await showActivity(
      tester,
      [_reply('n1', 'See you there'), _reply('n2', 'On my way')],
    );

    await tester.tap(find.text('On my way'));
    await tester.pump();
    expect(loaderShows(), isTrue);

    // Android back.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(loaderShows(), isFalse);

    threadContext.load();
    await settle(tester);

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(find.byType(ThreadViewPage), findsNothing);
    expect(navigator().canPop(), isFalse);
    expect(listedIds(), ['n1', 'n2']);
    verifyNever(() => notifications.dismissNotification(any()));
    await finish(tester);
  });

  testWidgets('a screen pushed over the loader stays on top', (tester) async {
    await showActivity(tester, [_reply('n1', 'See you there')]);

    await tester.tap(find.text('See you there'));
    await tester.pump();
    // A push notification opens another screen meanwhile.
    navigator().push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('From a push')),
    ));
    await settle(tester);

    threadContext.load();
    await settle(tester);

    expect(find.text('From a push'), findsOneWidget);
    expect(find.byType(ThreadViewPage), findsNothing);
    verifyNever(() => notifications.dismissNotification(any()));

    navigator().pop();
    await settle(tester);

    // Back on Activity, with no loader left behind.
    expect(loaderShows(), isFalse);
    expect(navigator().canPop(), isFalse);
    expect(listedIds(), ['n1']);
    await finish(tester);
  });

  testWidgets('a message that is gone says so and removes its item',
      (tester) async {
    await showActivity(
      tester,
      [_reply('n1', 'See you there'), _reply('n2', 'On my way')],
    );

    await tester.tap(find.text('On my way'));
    await tester.pump();
    threadContext.fail(
      NotFoundError(
          message: 'Message not found',
          userMessage: 'Message '
              'not found'),
    );
    await settle(tester);

    expect(find.text('This message is no longer available.'), findsOneWidget);
    expect(loaderShows(), isFalse);
    expect(find.byType(ThreadViewPage), findsNothing);
    verify(() => notifications.dismissNotification('n2')).called(1);
    expect(listedIds(), ['n1']);
    await finish(tester);
  });

  testWidgets('a connection problem shows why and keeps the item',
      (tester) async {
    await showActivity(tester, [_reply('n1', 'See you there')]);

    await tester.tap(find.text('See you there'));
    await tester.pump();
    threadContext.fail(
      NetworkError(
        message: 'Network connection error',
        userMessage: 'Unable to connect to the server. Please check your '
            'internet connection.',
      ),
    );
    await settle(tester);

    expect(
      find.text('Unable to connect to the server. Please check your internet '
          'connection.'),
      findsOneWidget,
    );
    expect(find.textContaining('Network connection error'), findsNothing);
    expect(loaderShows(), isFalse);
    expect(listedIds(), ['n1']);
    verifyNever(() => notifications.dismissNotification(any()));
    await finish(tester);
  });

  testWidgets('leaving Activity marks everything read after the page closes',
      (tester) async {
    await showActivity(tester, [_reply('n1', 'See you there')]);
    expect(
        container.read(notificationStateProvider).requireValue.unreadCount, 1);

    // The dashboard switches to another tab.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('Chats')),
        ),
      ),
    );
    await tester.pump();

    expect(
        container.read(notificationStateProvider).requireValue.unreadCount, 0);
    expect(listedIds(), ['n1']);
    verify(() => notifications.markAllAsRead()).called(1);
  });
}
