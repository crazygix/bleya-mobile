import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bleya/domain/entities/notification.dart';
import 'package:bleya/domain/repositories/notification_repository.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/chat_providers.dart';
import 'package:bleya/providers/notification_provider.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:bleya/services/auth_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_http_adapter.dart';
import '../fakes/fake_socket_service.dart';
import '../fakes/in_memory_secure_storage.dart';
import '../mocks.dart';

String _jwt(Map<String, Object> claims) {
  String encode(Map<String, Object> part) =>
      base64Url.encode(utf8.encode(jsonEncode(part))).replaceAll('=', '');
  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode(claims)}.sig';
}

/// An access token for [userId], shaped like the backend's.
String _accessToken(
  String userId, {
  Duration expiresIn = const Duration(hours: 1),
}) {
  final exp = DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return _jwt({'userId': userId, 'exp': exp});
}

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
    createdAt: DateTime(2026, 10, 1),
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
    'createdAt': DateTime(2026, 10, 1).millisecondsSinceEpoch,
  };
}

void main() {
  final aliceToken = _accessToken('alice');
  final aliceRefreshedToken =
      _accessToken('alice', expiresIn: const Duration(hours: 2));
  final bobToken = _accessToken('bob');

  group('sessionVersionProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      // Session-scoped providers keep it alive while the app runs.
      container.listen(sessionVersionProvider, (_, __) {});
    });

    void setToken(String? token) {
      container.read(tokenProvider.notifier).state = token;
    }

    int version() => container.read(sessionVersionProvider);

    test('changes on sign-in and on sign-out', () {
      expect(version(), 0);

      setToken(aliceToken);
      expect(version(), 1);

      setToken(null);
      expect(version(), 2);
    });

    test('does not change when the token is refreshed', () {
      setToken(aliceToken);
      final signedIn = version();

      setToken(aliceRefreshedToken);

      expect(version(), signedIn);
    });

    test('changes when another account signs in', () {
      setToken(aliceToken);
      final alice = version();

      setToken(bobToken);

      expect(version(), alice + 1);
    });

    test('treats an empty token as signed out', () {
      setToken(aliceToken);
      setToken('');
      final signedOut = version();

      setToken(null);

      expect(version(), signedOut);
    });
  });

  group('the user behind a token', () {
    test('is the token user id, or nothing when signed out', () {
      expect(sessionIdentityOf(aliceToken), 'alice');
      expect(sessionIdentityOf(aliceRefreshedToken), 'alice');
      expect(sessionIdentityOf(null), isNull);
      expect(sessionIdentityOf(''), isNull);
    });

    test('falls back to the sub claim, then to the token itself', () {
      expect(sessionIdentityOf(_jwt({'sub': 'carol'})), 'carol');
      expect(sessionIdentityOf('not-a-jwt'), 'not-a-jwt');
    });

    test('is the current user', () {
      final container = ProviderContainer(
        overrides: [tokenProvider.overrideWith((ref) => bobToken)],
      );
      addTearDown(container.dispose);

      expect(container.read(currentUserProvider), {'id': 'bob'});
    });
  });

  group('Activity across sessions', () {
    late MockNotificationRepository repository;
    late FakeSocketService socket;
    late ProviderContainer container;

    NotificationPage pageFor(String? token) {
      return switch (sessionIdentityOf(token)) {
        'alice' => NotificationPage(
            notifications: [_notification('alice-1')],
            unreadCount: 1,
          ),
        'bob' => NotificationPage(
            notifications: [_notification('bob-1')],
            unreadCount: 1,
          ),
        _ => const NotificationPage(notifications: [], unreadCount: 0),
      };
    }

    void answerFetches(Future<NotificationPage> Function() answer) {
      when(
        () => repository.fetchNotifications(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) => answer());
    }

    setUp(() {
      repository = MockNotificationRepository();
      socket = FakeSocketService();
      container = ProviderContainer(
        overrides: [
          tokenProvider.overrideWith((ref) => aliceToken),
          notificationRepositoryProvider.overrideWithValue(repository),
          socketServiceProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(container.dispose);
      // The server answers for whoever is signed in.
      answerFetches(() async => pageFor(container.read(tokenProvider)));
    });

    /// Listens as the dashboard does while it shows (the list, the badge and
    /// the live listener). Closing the result is the dashboard going away.
    List<ProviderSubscription<Object?>> showDashboard() {
      return [
        container.listen(notificationStateProvider, (_, __) {}),
        container.listen(notificationSocketListenerProvider, (_, __) {}),
      ];
    }

    Future<void> setToken(String? token) async {
      container.read(tokenProvider.notifier).state = token;
      await pumpEventQueue();
    }

    NotificationState activity() =>
        container.read(notificationStateProvider).requireValue;

    List<String> activityIds() =>
        activity().notifications.map((n) => n.id).toList();

    test('loads again after sign-out and sign-in, with one live handler',
        () async {
      final firstDashboard = showDashboard();
      await pumpEventQueue();

      expect(activityIds(), ['alice-1']);
      expect(socket.listenerCount('new_notification'), 1);
      expect(socket.listenerCount('message_removed'), 1);

      // Log out: the token is cleared while the dashboard still shows, then
      // the app goes back to the intro.
      await setToken(null);
      expect(activityIds(), isEmpty);
      expect(activity().unreadCount, 0);
      expect(socket.listenerCount('new_notification'), 0);
      expect(socket.listenerCount('message_removed'), 0);
      for (final subscription in firstDashboard) {
        subscription.close();
      }

      await setToken(bobToken);
      showDashboard();
      await pumpEventQueue();

      expect(activityIds(), ['bob-1']);
      expect(activity().unreadCount, 1);
      expect(socket.listenerCount('new_notification'), 1);
      expect(socket.listenerCount('message_removed'), 1);
      verify(
        () => repository.fetchNotifications(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).called(2);

      socket.emit('new_notification', _notificationEvent('bob-2'));

      expect(activityIds(), ['bob-2', 'bob-1']);
      expect(activity().unreadCount, 2);

      // Removals reach the new session's Activity too.
      socket.emit('message_removed', {
        'messageId': 'reply-bob-2',
        'roomId': 'room-1',
        'parentMessageId': 'thread-1',
      });

      expect(activityIds(), ['bob-1']);
      expect(activity().unreadCount, 1);
    });

    test('a sign-out while the socket connects registers no handler', () async {
      final connecting = socket.pendingConnect = Completer<void>();
      showDashboard();
      await pumpEventQueue();

      await setToken(null);
      connecting.complete();
      await pumpEventQueue();

      expect(socket.listenerCount('new_notification'), 0);
      expect(socket.listenerCount('message_removed'), 0);

      await setToken(bobToken);

      expect(socket.listenerCount('new_notification'), 1);
      expect(socket.listenerCount('message_removed'), 1);
    });

    test('a refresh that finishes after an account switch is dropped',
        () async {
      showDashboard();
      await pumpEventQueue();

      final latePage = Completer<NotificationPage>();
      answerFetches(() => latePage.future);
      final refreshing =
          container.read(notificationStateProvider.notifier).refresh();
      answerFetches(() async => pageFor(container.read(tokenProvider)));

      await setToken(null);
      await setToken(bobToken);
      expect(activityIds(), ['bob-1']);

      latePage.complete(pageFor(aliceToken));
      await refreshing;

      expect(activityIds(), ['bob-1']);
    });

    test('a next page that arrives after sign-out is dropped', () async {
      // A full first page, so there is more to load.
      answerFetches(
        () async => NotificationPage(
          notifications: [
            for (var i = 0; i < 20; i++) _notification('alice-$i'),
          ],
          unreadCount: 20,
          nextCursor: 'cursor-1',
        ),
      );
      showDashboard();
      await pumpEventQueue();

      final latePage = Completer<NotificationPage>();
      answerFetches(() => latePage.future);
      final loadingMore =
          container.read(notificationStateProvider.notifier).loadMore();

      await setToken(null);
      latePage.complete(
        NotificationPage(
          notifications: [_notification('alice-20')],
          unreadCount: 21,
        ),
      );
      await loadingMore;

      expect(activityIds(), isEmpty);
      expect(activity().unreadCount, 0);
    });
  });

  group('chat list across sessions', () {
    late MockRoomRepository repository;
    late FakeSocketService socket;
    late ProviderContainer container;

    List<Room> roomsFor(String? token) {
      final user = sessionIdentityOf(token);
      if (user == null) return const [];
      return [
        Room(
          id: '$user-room',
          name: 'Room of $user',
          unreadCount: 1,
          hasUnreadCount: true,
        ),
      ];
    }

    setUp(() {
      repository = MockRoomRepository();
      socket = FakeSocketService();
      container = ProviderContainer(
        overrides: [
          tokenProvider.overrideWith((ref) => aliceToken),
          roomRepositoryProvider.overrideWithValue(repository),
          socketServiceProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(container.dispose);
      when(() => repository.getJoinedRooms())
          .thenAnswer((_) async => roomsFor(container.read(tokenProvider)));
    });

    Future<void> setToken(String? token) async {
      container.read(tokenProvider.notifier).state = token;
      await pumpEventQueue();
    }

    List<String> roomIds() => container
        .read(roomsListProvider)
        .requireValue
        .map((item) => item.room.id)
        .toList();

    test('reloads for the next session with one summary listener', () async {
      final dashboard = container.listen(roomsListProvider, (_, __) {});
      await pumpEventQueue();

      expect(roomIds(), ['alice-room']);
      expect(socket.listenerCount('room_summary_updated'), 1);
      expect(socket.listenerCount('message_removed'), 1);

      await setToken(null);
      expect(roomIds(), isEmpty);
      expect(socket.listenerCount('room_summary_updated'), 0);
      expect(socket.listenerCount('message_removed'), 0);
      dashboard.close();

      await setToken(bobToken);
      container.listen(roomsListProvider, (_, __) {});
      await pumpEventQueue();

      expect(roomIds(), ['bob-room']);
      expect(socket.listenerCount('room_summary_updated'), 1);
      expect(socket.listenerCount('message_removed'), 1);
    });

    test('a sign-out while the list connects registers no listener', () async {
      final connecting = socket.pendingConnect = Completer<void>();
      container.listen(roomsListProvider, (_, __) {});
      await pumpEventQueue();

      await setToken(null);
      connecting.complete();
      await pumpEventQueue();

      expect(roomIds(), isEmpty);
      expect(socket.listenerCount('room_summary_updated'), 0);
      verifyNever(() => repository.getJoinedRooms());
    });

    test('a sign-out while the list loads leaves the signed-out list alone',
        () async {
      final aliceRooms = Completer<List<Room>>();
      when(() => repository.getJoinedRooms())
          .thenAnswer((_) => aliceRooms.future);
      container.listen(roomsListProvider, (_, __) {});
      await pumpEventQueue();

      await setToken(null);
      aliceRooms.complete(roomsFor(aliceToken));
      await pumpEventQueue();

      expect(roomIds(), isEmpty);
      expect(socket.listenerCount('room_summary_updated'), 0);
    });
  });

  group('token refresh across sessions', () {
    late Directory cookieDir;

    setUp(() async {
      cookieDir = await Directory.systemTemp.createTemp('bleya-session-test');
    });

    tearDown(() async {
      await cookieDir.delete(recursive: true);
    });

    test('a refresh that finishes after an account switch keeps the new user',
        () async {
      final refreshResponse = Completer<ResponseBody>();
      final adapter = FakeHttpAdapter((_) => refreshResponse.future);
      final container = ProviderContainer(
        overrides: [
          tokenProvider.overrideWith((ref) => aliceToken),
          cookieStoragePathProvider.overrideWithValue(cookieDir.path),
          secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        ],
      );
      addTearDown(container.dispose);

      final refreshing =
          container.read(authManagerProvider).refreshSession(fakeDio(adapter));
      await pumpEventQueue();
      expect(adapter.callsTo('/auth/refresh'), 1);

      container.read(tokenProvider.notifier).state = null;
      container.read(tokenProvider.notifier).state = bobToken;
      refreshResponse.complete(
        jsonResponse(200, {'token': aliceRefreshedToken}),
      );

      expect(await refreshing, isA<RefreshUnavailable>());
      expect(container.read(tokenProvider), bobToken);
    });
  });
}
