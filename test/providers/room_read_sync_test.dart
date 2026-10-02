import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/chat_providers.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/app_lifecycle.dart';
import '../fakes/fake_socket_service.dart';
import '../mocks.dart';

final _cityRoom = Room(id: 'room-x', name: 'Belgrade');
final _dm = Room(id: 'room-d', name: 'ana', type: 'private');

void main() {
  late FakeSocketService socket;
  late MockRoomRepository rooms;
  late MockMessageRepository messages;
  late List<String> readPosts;

  setUp(() {
    socket = FakeSocketService();
    rooms = MockRoomRepository();
    messages = MockMessageRepository();
    readPosts = [];
    when(() => rooms.getJoinedRooms()).thenAnswer((_) async => []);
    when(() => messages.markRoomAsRead(any())).thenAnswer((invocation) async {
      readPosts.add(invocation.positionalArguments.single as String);
      return 0;
    });
  });

  /// The app's providers, with the dashboard showing.
  ProviderContainer showDashboard({String? token = 'test-token'}) {
    final container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => token),
        socketServiceProvider.overrideWithValue(socket),
        roomRepositoryProvider.overrideWithValue(rooms),
        messageRepositoryProvider.overrideWithValue(messages),
      ],
    );
    container.listen(roomReadSyncProvider, (_, __) {});
    return container;
  }

  testWidgets(
      'posts the read position of the chat that stops showing and of the one '
      'that starts', (tester) async {
    final container = showDashboard();

    // The city room, then a DM over it, back to the room, then the chat list.
    final room = socket.claimRoom(_cityRoom);
    await tester.pump();
    final dm = socket.claimRoom(_dm);
    await tester.pump();
    socket.activateClaim(room);
    socket.releaseClaim(dm);
    await tester.pump();
    socket.releaseClaim(room);
    await tester.pump();

    expect(readPosts, [
      'room-x',
      'room-x',
      'room-d',
      'room-d',
      'room-x',
      'room-x',
    ]);
    container.dispose();
  });

  testWidgets('a thread opened from its room keeps the room showing',
      (tester) async {
    final container = showDashboard();
    final room = socket.claimRoom(_cityRoom);
    await tester.pump();

    final thread = socket.claimRoom(_cityRoom, threadId: 'thread-1');
    await tester.pump();
    socket.releaseClaim(thread);
    await tester.pump();

    expect(readPosts, ['room-x']);
    socket.releaseClaim(room);
    await tester.pump();
    container.dispose();
  });

  testWidgets("going inactive posts the open room's read position once",
      (tester) async {
    await setAppLifecycleState(tester, AppLifecycleState.resumed);
    final container = showDashboard();
    final room = socket.claimRoom(_cityRoom);
    await tester.pump();
    readPosts.clear();

    // To the background, through inactive and hidden, and back.
    await setAppLifecycleState(tester, AppLifecycleState.paused);
    await setAppLifecycleState(tester, AppLifecycleState.resumed);

    expect(readPosts, ['room-x']);
    socket.releaseClaim(room);
    await tester.pump();
    container.dispose();
  });

  testWidgets('posts nothing while signed out', (tester) async {
    final container = showDashboard(token: null);

    final room = socket.claimRoom(_cityRoom);
    await tester.pump();
    socket.releaseClaim(room);
    await tester.pump();

    expect(readPosts, isEmpty);
    container.dispose();
  });
}
