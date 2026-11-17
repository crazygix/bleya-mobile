import 'dart:async';

import 'package:bleya/domain/entities/notification.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/domain/repositories/notification_repository.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/chat_room_providers.dart';
import 'package:bleya/providers/notification_provider.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_socket_service.dart';
import '../mocks.dart';

final _createdAt = DateTime(2026, 10, 1, 9);

Notification _notification(
  String id, {
  String senderId = 'carol-id',
  String threadId = 'thread-1',
  bool isRead = false,
}) {
  return Notification(
    id: id,
    senderId: senderId,
    senderName: senderId.replaceFirst('-id', ''),
    roomId: 'room-1',
    roomName: 'Belgrade',
    roomType: 'public',
    messageId: 'reply-$id',
    threadId: threadId,
    previewText: 'See you there',
    type: 'reply',
    isRead: isRead,
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

/// A `message_removed` event as the server sends it.
Map<String, dynamic> _removalEvent(
  String messageId, {
  String? parentMessageId = 'thread-1',
}) {
  return {
    'messageId': messageId,
    'roomId': 'room-1',
    'parentMessageId': parentMessageId,
    'userId': 'carol-id',
    'createdAt': _createdAt.millisecondsSinceEpoch,
  };
}

/// A `new_notification` event as the server sends it.
Map<String, dynamic> _notificationEvent(
  String id, {
  String senderId = 'carol-id',
  String threadId = 'thread-1',
}) {
  return {
    'id': id,
    'sender': {'id': senderId, 'username': senderId.replaceFirst('-id', '')},
    'roomId': 'room-1',
    'roomName': 'Belgrade',
    'messageId': 'reply-$id',
    'threadId': threadId,
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

  group('loading the next page', () {
    Future<void> showFullFirstPage() async {
      answerFetches(
        () async => _page(
          [for (var i = 0; i < 20; i++) 'old-$i'],
          nextCursor: 'cursor-1',
        ),
      );
      await showActivity();
    }

    test('scrolling asks once while a page loads', () async {
      await showFullFirstPage();
      clearInteractions(repository);

      final nextPage = Completer<NotificationPage>();
      answerFetches(() => nextPage.future);
      // The page asks on every scroll frame near the end of the list.
      final loads = [for (var i = 0; i < 5; i++) notifier().loadMore()];
      nextPage.complete(_page(['old-20']));
      await Future.wait(loads);

      verifyFetches(1);
      expect(ids().last, 'old-20');
      expect(ids().where((id) => id == 'old-20'), hasLength(1));
    });

    test('a page that loads after the list changed keeps the change', () async {
      await showFullFirstPage();

      final nextPage = Completer<NotificationPage>();
      answerFetches(() => nextPage.future);
      final loadingMore = notifier().loadMore();

      socket.emit('new_notification', _notificationEvent('n-new'));
      await notifier().dismissNotification('old-3');
      nextPage.complete(_page(['old-20']));
      await loadingMore;

      expect(ids().first, 'n-new');
      expect(ids(), isNot(contains('old-3')));
      expect(ids().last, 'old-20');
    });

    test('a page that loads after Clean all adds nothing', () async {
      await showFullFirstPage();
      when(() => repository.dismissAll()).thenAnswer((_) async {});

      final nextPage = Completer<NotificationPage>();
      answerFetches(() => nextPage.future);
      final loadingMore = notifier().loadMore();

      await notifier().dismissAll();
      nextPage.complete(_page(['old-20']));
      await loadingMore;

      expect(ids(), isEmpty);
    });
  });

  group('moderator removals', () {
    test("a removed reply's item goes, with its unread count", () async {
      answerFetches(
        () async => NotificationPage(
          notifications: [
            _notification('n1'),
            _notification('n2'),
            _notification('n3', isRead: true),
          ],
          unreadCount: 2,
        ),
      );
      await showActivity();

      notifier().removeForMessage('reply-n2');
      expect(ids(), ['n1', 'n3']);
      expect(activity().requireValue.unreadCount, 1);

      // A read item lowers nothing.
      notifier().removeForMessage('reply-n3');
      expect(ids(), ['n1']);
      expect(activity().requireValue.unreadCount, 1);
    });

    test("a removed thread takes all of its replies' items", () async {
      answerFetches(
        () async => NotificationPage(
          notifications: [
            _notification('n1'),
            _notification('n2', threadId: 'thread-2'),
            _notification('n3'),
          ],
          unreadCount: 3,
        ),
      );
      await showActivity();

      notifier().removeForMessage('thread-1');

      expect(ids(), ['n2']);
      expect(activity().requireValue.unreadCount, 1);
    });

    test('a message_removed event takes its items out of Activity', () async {
      answerFetches(() async => _page(['n1', 'n2']));
      await showActivity();
      expect(socket.listenerCount('message_removed'), 1);

      socket.emit('message_removed', _removalEvent('reply-n1'));
      expect(ids(), ['n2']);

      socket.emit(
          'message_removed', _removalEvent('thread-1', parentMessageId: null));
      expect(ids(), isEmpty);
      expect(activity().requireValue.unreadCount, 0);
    });

    test('a removal during a refresh stays removed', () async {
      answerFetches(() async => _page(['n1']));
      await showActivity();

      // The server answered before it removed n2.
      final page = Completer<NotificationPage>();
      answerFetches(() => page.future);
      final refreshing = notifier().refresh(silent: true);
      socket.emit('message_removed', _removalEvent('reply-n2'));
      page.complete(_page(['n2', 'n1']));
      await refreshing;

      expect(ids(), ['n1']);
      expect(activity().requireValue.unreadCount, 1);
    });

    test('the removal listener goes with the others', () async {
      answerFetches(() async => _page(['n1']));
      await showActivity();
      expect(socket.listenerCount('message_removed'), 1);

      container.invalidate(notificationSocketListenerProvider);
      await pumpEventQueue();
      expect(socket.listenerCount('message_removed'), 1);
      expect(socket.listenerCount('new_notification'), 1);

      container.dispose();
      expect(socket.listenerCount('message_removed'), 0);
      expect(socket.listenerCount('new_notification'), 0);
    });
  });

  group('blocks made on this device', () {
    test("blocking someone hides their items at once, then loads again",
        () async {
      answerFetches(
        () async => NotificationPage(
          notifications: [
            _notification('n1', senderId: 'dan-id'),
            _notification('n2'),
            _notification('n3', isRead: true),
          ],
          unreadCount: 2,
        ),
      );
      await showActivity();
      clearInteractions(repository);

      final page = Completer<NotificationPage>();
      answerFetches(() => page.future);
      final blocking =
          notifier().applySenderBlockChange('carol-id', blocked: true);

      expect(ids(), ['n1']);
      expect(activity().requireValue.unreadCount, 1);
      expect(activity().isLoading, isFalse);
      await pumpEventQueue();
      verifyFetches(1);

      page.complete(
        NotificationPage(
          notifications: [_notification('n1', senderId: 'dan-id')],
          unreadCount: 1,
        ),
      );
      await blocking;
      expect(ids(), ['n1']);
    });

    test('a block during a refresh keeps them hidden in its result', () async {
      answerFetches(() async => _page(['n1']));
      await showActivity();

      // The refresh's answer predates the block.
      final page = Completer<NotificationPage>();
      answerFetches(() => page.future);
      final refreshing = notifier().refresh(silent: true);
      answerFetches(() async => _page([]));
      final blocking =
          notifier().applySenderBlockChange('carol-id', blocked: true);
      page.complete(_page(['n2', 'n1']));
      await refreshing;

      expect(ids(), isEmpty);
      expect(activity().requireValue.unreadCount, 0);
      await blocking;
    });

    test('unblocking someone loads again and brings their items back',
        () async {
      answerFetches(() async => _page([]));
      await showActivity();
      clearInteractions(repository);

      answerFetches(() async => _page(['n1', 'n2']));
      await notifier().applySenderBlockChange('carol-id', blocked: false);

      verifyFetches(1);
      expect(ids(), ['n1', 'n2']);
      expect(activity().requireValue.unreadCount, 2);
    });

    test('new notifications from someone just blocked are left out', () async {
      answerFetches(() async => _page(['n1']));
      await showActivity();

      container.read(sessionBlockedUserIdsProvider.notifier).state = {
        'carol-id',
      };
      socket.emit('new_notification', _notificationEvent('n2'));
      socket.emit(
        'new_notification',
        _notificationEvent('n3', senderId: 'dan-id'),
      );

      expect(ids(), ['n3', 'n1']);
      expect(activity().requireValue.unreadCount, 2);
    });
  });

  group('opening a thread', () {
    late List<String> threadReads;

    setUp(() {
      threadReads = [];
      when(() => repository.markThreadAsRead(any())).thenAnswer((invocation) {
        threadReads.add(invocation.positionalArguments.single as String);
        return Future.value(null);
      });
    });

    /// Whether each listed item is read, by id.
    Map<String, bool> readById() => {
          for (final n in activity().requireValue.notifications) n.id: n.isRead,
        };

    test('marks all of its items read, not only the one tapped', () async {
      answerFetches(() async => NotificationPage(
            notifications: [
              _notification('n3', threadId: 'thread-2'),
              _notification('n2'),
              _notification('n1'),
            ],
            unreadCount: 3,
          ));
      await showActivity();

      await notifier().markThreadAsRead('thread-1');

      expect(readById(), {'n3': false, 'n2': true, 'n1': true});
      expect(activity().requireValue.unreadCount, 1);
      expect(threadReads, ['thread-1']);
    });

    test("takes the server's count, which has the items not loaded yet",
        () async {
      // Three more of the thread's replies are on the next page.
      answerFetches(() async => NotificationPage(
            notifications: [_notification('n5'), _notification('n4')],
            unreadCount: 5,
            nextCursor: 'cursor-1',
          ));
      await showActivity();
      when(() => repository.markThreadAsRead('thread-1'))
          .thenAnswer((_) async => 0);

      await notifier().markThreadAsRead('thread-1');

      expect(activity().requireValue.unreadCount, 0);
    });

    test('a reply that arrives while the server answers stays listed and '
        'counted', () async {
      // Three more of the thread's replies are on the next page.
      answerFetches(() async => NotificationPage(
            notifications: [_notification('n2'), _notification('n1')],
            unreadCount: 5,
            nextCursor: 'cursor-1',
          ));
      await showActivity();
      final answer = Completer<int?>();
      when(() => repository.markThreadAsRead('thread-1'))
          .thenAnswer((_) => answer.future);

      final marking = notifier().markThreadAsRead('thread-1');
      // A reply in another thread arrives after the server counted.
      socket.emit(
        'new_notification',
        _notificationEvent('n3', threadId: 'thread-2'),
      );
      answer.complete(0);
      await marking;

      // The server's count predates n3, so the app keeps its own until the
      // next refresh.
      expect(readById(), {'n3': false, 'n2': true, 'n1': true});
      expect(activity().requireValue.unreadCount, 4);
    });

    test('a marking while a refresh loads stays in its result', () async {
      answerFetches(() async => _page(['n1']));
      await showActivity();

      final page = Completer<NotificationPage>();
      answerFetches(() => page.future);
      final refreshing = notifier().refresh(silent: true);
      await notifier().markThreadAsRead('thread-1');
      page.complete(_page(['n2', 'n1']));
      await refreshing;

      expect(readById(), {'n2': true, 'n1': true});
      expect(activity().requireValue.unreadCount, 0);
    });

    test('tells the server even before Activity has loaded', () async {
      final page = Completer<NotificationPage>();
      answerFetches(() => page.future);
      container.listen(notificationStateProvider, (_, __) {});

      await notifier().markThreadAsRead('thread-1');

      expect(threadReads, ['thread-1']);
      page.complete(_page([]));
    });

    test(
        'replies that arrived while the app was away from the open thread '
        'load as read, and the server is told', () async {
      answerFetches(() async => _page(['n1']));
      await showActivity();
      final thread = socket.claimRoom(
        Room(id: 'room-1', name: 'Belgrade'),
        threadId: 'thread-1',
      );
      await pumpEventQueue();

      // The app was in the background with the thread open: catching up
      // brings its new replies, and one from another thread.
      answerFetches(() async => NotificationPage(
            notifications: [
              _notification('n4', threadId: 'thread-2'),
              _notification('n3'),
              _notification('n2'),
              _notification('n1'),
            ],
            unreadCount: 4,
          ));
      socket.requestResync();
      await pumpEventQueue();

      expect(readById(), {'n4': false, 'n3': true, 'n2': true, 'n1': true});
      expect(activity().requireValue.unreadCount, 1);
      expect(threadReads, ['thread-1']);

      socket.releaseClaim(thread);
      await pumpEventQueue();
    });

    test('the first page loads with the open thread read', () async {
      final thread = socket.claimRoom(
        Room(id: 'room-1', name: 'Belgrade'),
        threadId: 'thread-1',
      );
      await pumpEventQueue();
      answerFetches(() async => NotificationPage(
            notifications: [
              _notification('n2', threadId: 'thread-2'),
              _notification('n1'),
            ],
            unreadCount: 2,
          ));

      await showActivity();

      expect(readById(), {'n2': false, 'n1': true});
      expect(activity().requireValue.unreadCount, 1);

      socket.releaseClaim(thread);
      await pumpEventQueue();
    });
  });
}
