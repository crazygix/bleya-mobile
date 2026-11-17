import 'dart:async';

import 'package:bleya/domain/entities/push_notification_payload.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/notification_tray_provider.dart';
import 'package:bleya/services/push_messaging_service.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/app_lifecycle.dart';
import '../fakes/fake_notification_tray_service.dart';
import '../fakes/fake_socket_service.dart';

class MockPushMessagingService extends Mock implements PushMessagingService {}

/// A socket whose chat on screen the test sets.
class _OpenChatSocket extends FakeSocketService {
  final ValueNotifier<OpenChat> chat = ValueNotifier(OpenChat.none);

  @override
  ValueListenable<OpenChat> get openChat => chat;
}

const _roomMessage = PushNotificationPayload(
  type: PushNotificationType.message,
  roomId: 'room-1',
  messageId: 'msg-1',
  senderId: 'user-2',
);

const _reply = PushNotificationPayload(
  type: PushNotificationType.reply,
  roomId: 'room-1',
  messageId: 'msg-2',
  senderId: 'user-2',
  threadId: 'thread-1',
);

ForegroundPush _push(PushNotificationPayload payload, String messageId) {
  return ForegroundPush(
    payload: payload,
    messageId: messageId,
    title: 'alice',
    body: 'Hi',
  );
}

void main() {
  late FakeNotificationTrayService tray;

  setUp(() {
    tray = FakeNotificationTrayService();
  });

  group('clearing the open chat\'s notifications', () {
    late _OpenChatSocket socket;

    setUp(() {
      socket = _OpenChatSocket();
    });

    /// The app's providers, with the dashboard showing.
    void showDashboard() {
      final container = ProviderContainer(
        overrides: [
          notificationTrayServiceProvider.overrideWithValue(tray),
          socketServiceProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(container.dispose);
      container.listen(openChatNotificationsClearingProvider, (_, __) {});
    }

    testWidgets("clears a room's, then a thread's, as each opens",
        (tester) async {
      await setAppLifecycleState(tester, AppLifecycleState.resumed);
      showDashboard();

      socket.chat.value = const OpenChat(roomId: 'room-1');
      socket.chat.value =
          const OpenChat(roomId: 'room-1', threadId: 'thread-1');
      socket.chat.value = const OpenChat(threadId: 'thread-2');
      // Back on the chat list.
      socket.chat.value = OpenChat.none;

      expect(tray.clearedChats, [
        '-/-',
        'room-1/-',
        'room-1/thread-1',
        '-/thread-2',
        '-/-',
      ]);
      expect(tray.clears, 0);
    });

    testWidgets('clears the open chat again when the app comes back',
        (tester) async {
      await setAppLifecycleState(tester, AppLifecycleState.resumed);
      showDashboard();
      socket.chat.value = const OpenChat(roomId: 'room-1');
      tray.clearedChats.clear();

      // Pushes for the open chat arrive while the app is in the background.
      await setAppLifecycleState(tester, AppLifecycleState.paused);
      expect(tray.clearedChats, isEmpty);
      await setAppLifecycleState(tester, AppLifecycleState.resumed);

      expect(tray.clearedChats, ['room-1/-']);
      expect(tray.clears, 0);
    });

    testWidgets('does nothing where the app gets no pushes', (tester) async {
      tray = FakeNotificationTrayService(isSupported: false);
      showDashboard();

      socket.chat.value = const OpenChat(roomId: 'room-1');

      expect(tray.clearedChats, isEmpty);
    });
  });

  group('isPayloadForOpenChat', () {
    test('a message is for its room with no thread open', () {
      expect(
        isPayloadForOpenChat(_roomMessage, const OpenChat(roomId: 'room-1')),
        isTrue,
      );
      expect(
        isPayloadForOpenChat(
          _roomMessage,
          const OpenChat(roomId: 'room-1', threadId: 'thread-1'),
        ),
        isFalse,
      );
      expect(
        isPayloadForOpenChat(_roomMessage, const OpenChat(roomId: 'room-2')),
        isFalse,
      );
      expect(isPayloadForOpenChat(_roomMessage, OpenChat.none), isFalse);
    });

    test('a reply is for its thread', () {
      expect(
        isPayloadForOpenChat(_reply, const OpenChat(threadId: 'thread-1')),
        isTrue,
      );
      expect(
        isPayloadForOpenChat(_reply, const OpenChat(roomId: 'room-1')),
        isFalse,
      );
    });
  });

  group('inAppBannersProvider', () {
    late _OpenChatSocket socket;
    late MockPushMessagingService push;
    late StreamController<ForegroundPush> pushes;

    setUp(() {
      socket = _OpenChatSocket();
      push = MockPushMessagingService();
      pushes = StreamController<ForegroundPush>.broadcast(sync: true);
      when(() => push.onForegroundMessage).thenAnswer((_) => pushes.stream);
    });

    tearDown(() => pushes.close());

    ProviderContainer startBanners({String? token = 'token'}) {
      final container = ProviderContainer(
        overrides: [
          notificationTrayServiceProvider.overrideWithValue(tray),
          socketServiceProvider.overrideWithValue(socket),
          pushMessagingServiceProvider.overrideWithValue(push),
        ],
      );
      addTearDown(container.dispose);
      container.read(tokenProvider.notifier).state = token;
      container.listen(inAppBannersProvider, (_, __) {});
      return container;
    }

    group('on Android, where the app shows the banner', () {
      test('shows pushes for other chats', () {
        startBanners();
        socket.chat.value = const OpenChat(roomId: 'room-2');

        pushes.add(_push(_roomMessage, 'fcm-1'));
        pushes.add(_push(_reply, 'fcm-2'));

        expect(tray.banners, ['fcm-1', 'fcm-2']);
      });

      test('shows none for the chat on screen', () {
        startBanners();
        socket.chat.value = const OpenChat(roomId: 'room-1');
        pushes.add(_push(_roomMessage, 'fcm-1'));

        socket.chat.value = const OpenChat(threadId: 'thread-1');
        pushes.add(_push(_reply, 'fcm-2'));

        expect(tray.banners, isEmpty);
      });

      test('shows none while signed out', () {
        startBanners(token: null);

        pushes.add(_push(_roomMessage, 'fcm-1'));

        expect(tray.banners, isEmpty);
      });

      test('stops when the app goes away', () {
        startBanners().dispose();

        pushes.add(_push(_roomMessage, 'fcm-1'));

        expect(tray.banners, isEmpty);
        expect(pushes.hasListener, isFalse);
      });
    });

    group('on iOS, where the system shows the push', () {
      const roomData = {
        'type': 'message',
        'roomId': 'room-1',
        'messageId': 'msg-1',
        'senderId': 'user-2',
      };

      setUp(() {
        tray = FakeNotificationTrayService(showsBannersItself: false);
      });

      test('lets pushes for other chats show', () {
        startBanners();
        socket.chat.value = const OpenChat(roomId: 'room-2');

        expect(tray.bannerQuestions!(roomData), isTrue);
        verifyNever(() => push.onForegroundMessage);
      });

      test('keeps pushes for the chat on screen from showing', () {
        startBanners();
        socket.chat.value = const OpenChat(roomId: 'room-1');

        expect(tray.bannerQuestions!(roomData), isFalse);
      });

      test('keeps every push from showing while signed out', () {
        startBanners(token: null);

        expect(tray.bannerQuestions!(roomData), isFalse);
        expect(tray.bannerQuestions!(const {'other': 'push'}), isFalse);
      });

      test('stops answering when the app goes away', () {
        startBanners().dispose();

        expect(tray.bannerQuestions, isNull);
      });
    });
  });
}
