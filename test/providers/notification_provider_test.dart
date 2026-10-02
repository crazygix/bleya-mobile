import 'dart:async';

import 'package:bleya/domain/entities/notification.dart';
import 'package:bleya/domain/repositories/notification_repository.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/notification_provider.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_socket_service.dart';
import '../mocks.dart';

final _createdAt = DateTime(2026, 10, 1, 9);

Notification _notification(String id) {
  return Notification(
    id: id,
    senderId: 'carol-id',
    senderName: 'carol',
    roomId: 'room-1',
    roomName: 'Belgrade',
    roomType: 'public',
    messageId: 'reply-$id',
    threadId: 'thread-1',
    previewText: 'See you there',
    type: 'reply',
    isRead: false,
    createdAt: _createdAt,
  );
}

/// A first page of Activity holding [ids], newest first, all unread.
NotificationPage _page(List<String> ids, {String? nextCursor}) {
  return NotificationPage(
    notifications: [for (final id in ids) _notification(id)],
    unreadCount: ids.length,
    nextCursor: nextCursor,
  );
}

/// A `new_notification` event as the server sends it.
Map<String, dynamic> _notificationEvent(String id) {
  return {
    'id': id,
    'sender': {'id': 'carol-id', 'username': 'carol'},
    'roomId': 'room-1',
    'roomName': 'Belgrade',
    'messageId': 'reply-$id',
    'threadId': 'thread-1',
    'previewText': 'See you there',
    'type': 'reply',
    'read': false,
    'createdAt': _createdAt.millisecondsSinceEpoch,
  };
}

void main() {
  late MockNotificationRepository repository;
  late FakeSocketService socket;
  late ProviderContainer container;

  setUp(() {
    repository = MockNotificationRepository();
    socket = FakeSocketService();
    container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => 'test-token'),
        notificationRepositoryProvider.overrideWithValue(repository),
        socketServiceProvider.overrideWithValue(socket),
      ],
    );
    addTearDown(container.dispose);
    when(() => repository.dismissNotification(any())).thenAnswer((_) async {});
  });

  void answerFetches(Future<NotificationPage> Function() answer) {
    when(
      () => repository.fetchNotifications(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer((_) => answer());
  }

  void verifyFetches(int count) {
    verify(
      () => repository.fetchNotifications(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).called(count);
  }

  /// Shows Activity as the dashboard does: the list and its live listener.
  Future<void> showActivity() async {
    container.listen(notificationStateProvider, (_, __) {});
    container.listen(notificationSocketListenerProvider, (_, __) {});
    await pumpEventQueue();
  }

  NotificationNotifier notifier() =>
      container.read(notificationStateProvider.notifier);

  AsyncValue<NotificationState> activity() =>
      container.read(notificationStateProvider);

  List<String> ids() =>
      activity().requireValue.notifications.map((n) => n.id).toList();

  test('a silent refresh keeps the list while it loads and when it fails',
      () async {
    answerFetches(() async => _page(['n1']));
    await showActivity();

    final page = Completer<NotificationPage>();
    answerFetches(() => page.future);
    final refreshing = notifier().refresh(silent: true);
    expect(activity().isLoading, isFalse);
    expect(ids(), ['n1']);

    page.completeError(Exception('offline'));
    await refreshing;

    expect(activity().hasError, isFalse);
    expect(ids(), ['n1']);
  });

  test('a silent refresh keeps notifications that arrive while it loads',
      () async {
    answerFetches(() async => _page(['n1']));
    await showActivity();

    // n3 arrives live, after the server answered.
    final page = Completer<NotificationPage>();
    answerFetches(() => page.future);
    final refreshing = notifier().refresh(silent: true);
    socket.emit('new_notification', _notificationEvent('n3'));
    expect(ids(), ['n3', 'n1']);
    page.complete(_page(['n2', 'n1']));
    await refreshing;

    expect(ids(), ['n3', 'n2', 'n1']);
    expect(activity().requireValue.unreadCount, 3);

    // n4 arrives live, and the server's answer has it too: listed once.
    final nextPage = Completer<NotificationPage>();
    answerFetches(() => nextPage.future);
    final refreshingAgain = notifier().refresh(silent: true);
    socket.emit('new_notification', _notificationEvent('n4'));
    nextPage.complete(_page(['n4', 'n3', 'n2', 'n1']));
    await refreshingAgain;

    expect(ids(), ['n4', 'n3', 'n2', 'n1']);
    expect(activity().requireValue.unreadCount, 4);
  });

  test('a dismissal while a refresh loads stays dismissed', () async {
    answerFetches(() async => _page(['n2', 'n1']));
    await showActivity();

    final page = Completer<NotificationPage>();
    answerFetches(() => page.future);
    final refreshing = notifier().refresh(silent: true);
    await notifier().dismissNotification('n1');
    page.complete(_page(['n2', 'n1']));
    await refreshing;

    expect(ids(), ['n2']);
    expect(activity().requireValue.unreadCount, 1);
  });

  test('overlapping refreshes run one after another', () async {
    answerFetches(() async => _page(['n1']));
    await showActivity();
    clearInteractions(repository);

    final first = Completer<NotificationPage>();
    answerFetches(() => first.future);
    final firstRefresh = notifier().refresh(silent: true);
    final second = Completer<NotificationPage>();
    answerFetches(() => second.future);
    final secondRefresh = notifier().refresh(silent: true);
    await pumpEventQueue();
    verifyFetches(1);

    first.complete(_page(['n2', 'n1']));
    await firstRefresh;
    await pumpEventQueue();
    expect(ids(), ['n2', 'n1']);
    verifyFetches(1);

    second.complete(_page(['n3', 'n2', 'n1']));
    await secondRefresh;
    expect(ids(), ['n3', 'n2', 'n1']);
  });

  test('a pull to refresh still shows loading', () async {
    answerFetches(() async => _page(['n1']));
    await showActivity();

    final page = Completer<NotificationPage>();
    answerFetches(() => page.future);
    final refreshing = notifier().refresh();
    expect(activity().isLoading, isTrue);

    page.complete(_page(['n2', 'n1']));
    await refreshing;
    expect(ids(), ['n2', 'n1']);
  });

  test('catches up silently when the socket asks', () async {
    answerFetches(() async => _page(['n1']));
    await showActivity();

    final page = Completer<NotificationPage>();
    answerFetches(() => page.future);
    socket.requestResync();
    await pumpEventQueue();
    expect(activity().isLoading, isFalse);
    expect(ids(), ['n1']);

    page.complete(_page(['n2', 'n1']));
    await pumpEventQueue();

    expect(ids(), ['n2', 'n1']);
  });

  test('a first load that fails loads again when the socket asks', () async {
    answerFetches(() async => throw Exception('offline'));
    await showActivity();

    expect(activity().hasError, isTrue);
    expect(socket.resyncOnConnectRequests, 1);

    answerFetches(() async => _page(['n1']));
    socket.requestResync();
    await pumpEventQueue();

    expect(ids(), ['n1']);
  });

  test('a next page that arrives after a refresh replaced the list is dropped',
      () async {
    answerFetches(
      () async => _page(
        [for (var i = 0; i < 20; i++) 'old-$i'],
        nextCursor: 'cursor-1',
      ),
    );
    await showActivity();

    final nextPage = Completer<NotificationPage>();
    answerFetches(() => nextPage.future);
    final loadingMore = notifier().loadMore();
    answerFetches(() async => _page(['new-1']));
    await notifier().refresh(silent: true);
    nextPage.complete(_page(['old-20']));
    await loadingMore;

    expect(ids(), ['new-1']);
  });
}
