import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/domain/repositories/notification_repository.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/notification_provider.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_socket_service.dart';
import '../mocks.dart';

final _cityRoom = Room(id: 'room-x', name: 'Belgrade');
final _dm = Room(id: 'room-d', name: 'ana', type: 'private');

void main() {
  late FakeSocketService socket;
  late MockNotificationRepository notifications;
  late List<String> threadReads;

  setUp(() {
    socket = FakeSocketService();
    notifications = MockNotificationRepository();
    threadReads = [];
    when(
      () => notifications.fetchNotifications(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer(
      (_) async => const NotificationPage(notifications: [], unreadCount: 0),
    );
    when(() => notifications.markThreadAsRead(any())).thenAnswer((invocation) {
      threadReads.add(invocation.positionalArguments.single as String);
      return Future.value(null);
    });
  });

  /// The app's providers, with the dashboard showing.
  void showDashboard({String? token = 'test-token'}) {
    final container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => token),
        socketServiceProvider.overrideWithValue(socket),
        notificationRepositoryProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
    container.listen(threadReadSyncProvider, (_, __) {});
  }

  test('marks each thread that opens read, wherever it opens from', () async {
    showDashboard();

    // A thread from its room, then one opened from Activity or a push.
    final room = socket.claimRoom(_cityRoom);
    await pumpEventQueue();
    final fromRoom = socket.claimRoom(_cityRoom, threadId: 'thread-1');
    await pumpEventQueue();
    socket.releaseClaim(fromRoom);
    socket.releaseClaim(room);
    await pumpEventQueue();
    final fromActivity = socket.claimRoom(_cityRoom, threadId: 'thread-2');
    await pumpEventQueue();
    socket.releaseClaim(fromActivity);
    await pumpEventQueue();

    expect(threadReads, ['thread-1', 'thread-2']);
  });

  test('marks a thread again when it comes back on top', () async {
    showDashboard();
    final thread = socket.claimRoom(_cityRoom, threadId: 'thread-1');
    await pumpEventQueue();

    // "Say hey" opens a DM over the thread, and the user comes back. Replies
    // in the thread meanwhile made new items.
    final dm = socket.claimRoom(_dm);
    await pumpEventQueue();
    socket.activateClaim(thread);
    socket.releaseClaim(dm);
    await pumpEventQueue();

    expect(threadReads, ['thread-1', 'thread-1']);
    socket.releaseClaim(thread);
    await pumpEventQueue();
  });

  test('marks nothing while signed out', () async {
    showDashboard(token: null);

    final thread = socket.claimRoom(_cityRoom, threadId: 'thread-1');
    await pumpEventQueue();
    socket.releaseClaim(thread);
    await pumpEventQueue();

    expect(threadReads, isEmpty);
  });
}
