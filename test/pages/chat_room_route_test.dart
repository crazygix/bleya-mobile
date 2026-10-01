import 'package:bleya/domain/entities/direct_chat_status.dart';
import 'package:bleya/domain/entities/message.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/domain/repositories/message_repository.dart';
import 'package:bleya/pages/chat_room_page.dart';
import 'package:bleya/pages/thread_view_page.dart';
import 'package:bleya/platform/app_route.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/chat_room_providers.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:bleya/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_socket_service.dart';
import '../mocks.dart';

final _cityRoom = Room(id: 'room-x', name: 'Belgrade, Serbia');
final _dm = Room(
  id: 'room-d',
  name: 'ana',
  type: 'private',
  otherUserId: 'user-ana',
);

Message _message(String id, String text, {int minute = 0}) {
  return Message(
    id: id,
    roomId: _cityRoom.id,
    userId: 'user-2',
    username: 'bob',
    text: text,
    createdAt: DateTime(2026, 1, 1, 10, minute),
  );
}

/// A room_joined event for [room] as the server sends it.
Map<String, dynamic> _roomJoined(Room room, List<Message> messages) {
  return {
    'room': {'id': room.id, 'name': room.name, 'type': room.type},
    'messages': [
      for (final message in messages)
        {
          'id': message.id,
          'roomId': message.roomId,
          'userId': message.userId,
          'username': message.username,
          'text': message.text,
          'createdAt': message.createdAt.millisecondsSinceEpoch,
        },
    ],
    'pagination': {'hasMore': false, 'nextCursor': null},
    'lastReadAt': null,
  };
}

/// A profile screen: it holds no room, as the real one doesn't.
class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Profile'));
  }
}

void main() {
  late FakeSocketService socket;
  late MockRoomRepository rooms;
  late MockMessageRepository messages;
  late ProviderContainer container;
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() {
    socket = FakeSocketService();
    rooms = MockRoomRepository();
    messages = MockMessageRepository();
    navigatorKey = GlobalKey<NavigatorState>();
    when(() => rooms.getJoinedRooms()).thenAnswer((_) async => []);
    when(() => rooms.getDirectChatStatus(any())).thenAnswer(
      (_) async => const DirectChatStatus(
        hasChat: true,
        roomId: 'room-d',
        isBlockedByMe: false,
        isBlockedByOtherUser: false,
        canSendMessage: true,
        isDeletedByMe: false,
      ),
    );
    when(() => messages.markRoomAsRead(any())).thenAnswer((_) async => 0);
    when(() => messages.getThread(any())).thenAnswer(
      (_) async => ThreadData(
        parentMessage: _message('thread-1', 'Coffee?'),
        replies: const [],
      ),
    );
    container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => 'test-token'),
        socketServiceProvider.overrideWithValue(socket),
        roomRepositoryProvider.overrideWithValue(rooms),
        messageRepositoryProvider.overrideWithValue(messages),
      ],
    );
    addTearDown(container.dispose);
  });

  NavigatorState navigator() => navigatorKey.currentState!;

  List<String> claimedRooms() =>
      socket.claims.map((claim) => claim.room.id).toList();

  Future<void> showApp(WidgetTester tester) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [appRouteObserver],
          home: const Scaffold(body: Text('Chats')),
        ),
      ),
    );
  }

  /// Lets the current route transition finish. The loading skeleton animates
  /// forever, so this can't wait for the screen to settle.
  Future<void> finishTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> push(WidgetTester tester, Widget screen) async {
    navigator().push(AppRoute.build(builder: (_) => screen));
    await finishTransition(tester);
  }

  Future<void> pop(WidgetTester tester) async {
    navigator().pop();
    await finishTransition(tester);
  }

  /// Goes back to the chat list, so the screens close, their claims end and
  /// their controllers are disposed while the app still runs.
  Future<void> closeApp(WidgetTester tester) async {
    navigator().popUntil((route) => route.isFirst);
    await finishTransition(tester);
    await tester.pump();
  }

  testWidgets(
      'a second screen for the open room leaves its messages alone and keeps '
      'the room claimed', (tester) async {
    await showApp(tester);
    await push(tester, ChatRoomPage(room: _cityRoom));
    socket.emit(
      'room_joined',
      _roomJoined(_cityRoom, [
        _message('m1', 'Anyone at the market?'),
        _message('m2', 'On my way', minute: 1),
      ]),
    );
    await tester.pump();
    socket.snapshotRequests.clear();

    // A push opens the same room again.
    await push(tester, ChatRoomPage(room: _cityRoom));
    expect(claimedRooms(), ['room-x', 'room-x']);
    await pop(tester);

    expect(
      container.read(roomMessagesProvider('room-x')).map((m) => m.id),
      ['m1', 'm2'],
    );
    expect(find.text('On my way'), findsOneWidget);
    expect(claimedRooms(), ['room-x']);
    // The second screen found the room loaded and asked for nothing.
    expect(socket.snapshotRequests, isEmpty);

    await closeApp(tester);
    expect(claimedRooms(), isEmpty);
  });

  testWidgets('closing a DM over a room gives the socket back to the room',
      (tester) async {
    await showApp(tester);
    await push(tester, ChatRoomPage(room: _cityRoom));
    await push(tester, ChatRoomPage(room: _dm));
    expect(claimedRooms(), ['room-x', 'room-d']);

    await pop(tester);

    expect(socket.activatedRoomIds, ['room-x']);
    expect(claimedRooms(), ['room-x']);
    expect(socket.openChat.value, const OpenChat(roomId: 'room-x'));

    await closeApp(tester);
  });

  testWidgets(
      'Say hey: a DM that replaced a profile over the room gives the socket '
      'back to the room', (tester) async {
    await showApp(tester);
    await push(tester, ChatRoomPage(room: _cityRoom));
    await push(tester, const _ProfileScreen());
    expect(claimedRooms(), ['room-x']);

    navigator().pushReplacement(
      AppRoute.build(builder: (_) => ChatRoomPage(room: _dm)),
    );
    await finishTransition(tester);
    expect(claimedRooms(), ['room-x', 'room-d']);

    await pop(tester);

    expect(socket.activatedRoomIds, ['room-x']);
    expect(claimedRooms(), ['room-x']);

    await closeApp(tester);
  });

  testWidgets('a thread screen removed without a pop releases its claim',
      (tester) async {
    await showApp(tester);
    await push(tester, ChatRoomPage(room: _cityRoom));
    final threadRoute = AppRoute.build<void>(
      builder: (_) => ThreadViewPage(
        parentMessage: _message('thread-1', 'Coffee?'),
        room: _cityRoom,
      ),
    );
    navigator().push(threadRoute);
    await finishTransition(tester);
    expect(socket.claims.last.threadId, 'thread-1');

    navigator().removeRoute(threadRoute);
    await finishTransition(tester);

    expect(claimedRooms(), ['room-x']);
    expect(socket.claims.single.threadId, isNull);

    await closeApp(tester);
  });

  testWidgets(
      "a room that doesn't open in 10 s shows the error, and Try again "
      'retries', (tester) async {
    await showApp(tester);
    await push(tester, ChatRoomPage(room: _cityRoom));
    expect(find.text("Couldn't open this chat"), findsNothing);

    // There is no connection, so the join never happens.
    await tester.pump(const Duration(seconds: 10));

    expect(find.text("Couldn't open this chat"), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(socket.retriedJoins, ['room-x']);
    expect(find.text("Couldn't open this chat"), findsNothing);

    socket.emit('room_joined', _roomJoined(_cityRoom, [_message('m1', 'Hi!')]));
    await tester.pump();
    expect(find.text('Hi!'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets("shows the server's reason when it refused the room",
      (tester) async {
    await showApp(tester);
    await push(tester, ChatRoomPage(room: _cityRoom));

    socket.failJoin(
      'room-x',
      const SocketErrorData(
        code: 'VALIDATION_ERROR',
        message: 'You can only join up to 5 group chats at a time.',
      ),
    );
    await tester.pump();

    expect(find.text("Couldn't open this chat"), findsOneWidget);
    expect(
      find.text('You can only join up to 5 group chats at a time.'),
      findsOneWidget,
    );

    await closeApp(tester);
  });
}
