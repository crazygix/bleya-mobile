import 'dart:io';

import 'package:bleya/services/notification_tray_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('bleya/notifications');
  late List<MethodCall> calls;

  void answerCalls(Future<Object?> Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  setUp(() {
    calls = [];
    answerCalls((call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() => answerCalls(null));

  test('clears the notifications through the bleya/notifications channel',
      () async {
    await NotificationTrayService(isSupported: true).clearAll();

    expect(calls.single.method, 'clearAll');
    expect(calls.single.arguments, isNull);
  });

  test('does nothing where the app gets no pushes', () async {
    await NotificationTrayService(isSupported: false).clearAll();

    expect(calls, isEmpty);
  });

  test('clears on iPhones and Android phones by default', () {
    expect(
      NotificationTrayService().isSupported,
      Platform.isIOS || Platform.isAndroid,
    );
  });

  test('never throws when the platform fails or has no channel', () async {
    final tray = NotificationTrayService(isSupported: true);

    answerCalls((call) async {
      throw PlatformException(code: 'clear-failed');
    });
    await expectLater(tray.clearAll(), completes);

    answerCalls(null);
    await expectLater(tray.clearAll(), completes);
  });
}
