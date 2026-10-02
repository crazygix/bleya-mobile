import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/app_lifecycle.dart';
import '../fakes/fake_io_socket.dart';

final _room = Room(id: 'room-x', name: 'Belgrade');

void main() {
  late List<FakeIoSocket> sockets;
  late SocketService service;

  FakeIoSocket socket() => sockets.last;

  setUp(() {
    sockets = [];
    service = SocketService(socketFactory: (url, options) {
      final socket = FakeIoSocket(options);
      sockets.add(socket);
      return socket;
    });
    service.setToken('token-1');
  });

  /// Opens [_room], with the server accepting the connection.
  Future<void> openRoom(WidgetTester tester) async {
    service.claimRoom(_room);
    await tester.pump();
    socket().acceptConnection();
    await tester.pump();
  }

  /// Signs out, which also stops the service's timers.
  Future<void> signOut(WidgetTester tester) async {
    service.disconnect();
    await tester.pump();
  }

  testWidgets('the socket leaves in the background and comes back on resume',
      (tester) async {
    await setAppLifecycleState(tester, AppLifecycleState.resumed);
    final lifecycle = followAppLifecycle(service);
    await openRoom(tester);

    await setAppLifecycleState(tester, AppLifecycleState.hidden);
    expect(service.isInForeground, isFalse);
    expect(socket().disconnectCalls, 1);
    expect(socket().connected, isFalse);

    await setAppLifecycleState(tester, AppLifecycleState.paused);
    expect(socket().disconnectCalls, 1);

    await setAppLifecycleState(tester, AppLifecycleState.resumed);
    expect(service.isInForeground, isTrue);
    expect(socket().connectCalls, 2);

    lifecycle.dispose();
    await signOut(tester);
  });

  testWidgets('a detached app counts as in the background', (tester) async {
    await setAppLifecycleState(tester, AppLifecycleState.resumed);
    final lifecycle = followAppLifecycle(service);

    await setAppLifecycleState(tester, AppLifecycleState.detached);

    expect(service.isInForeground, isFalse);
    lifecycle.dispose();
    await signOut(tester);
  });

  testWidgets(
      'an inactive app keeps the chat live, as with the app switcher or '
      'Face ID', (tester) async {
    await setAppLifecycleState(tester, AppLifecycleState.resumed);
    final lifecycle = followAppLifecycle(service);
    await openRoom(tester);

    await setAppLifecycleState(tester, AppLifecycleState.inactive);
    expect(service.isInForeground, isTrue);
    expect(socket().connected, isTrue);

    await setAppLifecycleState(tester, AppLifecycleState.resumed);
    expect(socket().disconnectCalls, 0);
    expect(socket().connectCalls, 1);

    lifecycle.dispose();
    await signOut(tester);
  });

  testWidgets('an app started in the background connects once it is resumed',
      (tester) async {
    await setAppLifecycleState(tester, AppLifecycleState.paused);
    final lifecycle = followAppLifecycle(service);
    expect(service.isInForeground, isFalse);

    service.claimRoom(_room);
    await tester.pump();
    expect(socket().connectCalls, 0);

    await setAppLifecycleState(tester, AppLifecycleState.resumed);
    expect(socket().connectCalls, 1);

    lifecycle.dispose();
    await signOut(tester);
  });

  testWidgets('counts as in the foreground until the first state arrives',
      (tester) async {
    expect(WidgetsBinding.instance.lifecycleState, isNull);
    final lifecycle = followAppLifecycle(service);

    service.claimRoom(_room);
    await tester.pump();

    expect(service.isInForeground, isTrue);
    expect(socket().connectCalls, 1);
    lifecycle.dispose();
    await signOut(tester);
  });
}
