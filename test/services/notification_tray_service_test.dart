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

  test("clears one chat's notifications through the channel", () async {
    final tray = NotificationTrayService(isSupported: true);

    await tray.clearChat(roomId: 'room-1');
    await tray.clearChat(threadId: 'thread-1');

    expect([for (final call in calls) call.method], ['clearChat', 'clearChat']);
    expect([
      for (final call in calls) call.arguments
    ], [
      {'roomId': 'room-1', 'threadId': null},
      {'roomId': null, 'threadId': 'thread-1'},
    ]);
  });

  test('clears no chat without one, or where the app gets no pushes', () async {
    await NotificationTrayService(isSupported: true).clearChat();
    await NotificationTrayService(isSupported: false)
        .clearChat(roomId: 'room-1');

    expect(calls, isEmpty);
  });

  test('never throws when clearing a chat fails', () async {
    answerCalls((call) async {
      throw PlatformException(code: 'clear-failed');
    });

    await expectLater(
      NotificationTrayService(isSupported: true).clearChat(roomId: 'room-1'),
      completes,
    );
  });

  group('banners while the app is open', () {
    test('shows a banner through the channel on Android', () async {
      await NotificationTrayService(isSupported: true, showsBannersItself: true)
          .showBanner(
        messageId: 'fcm-1',
        title: 'alice',
        body: 'Hi',
        sentTime: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      expect(calls.single.method, 'showBanner');
      expect(calls.single.arguments, {
        'messageId': 'fcm-1',
        'title': 'alice',
        'body': 'Hi',
        'sentTime': 1700000000000,
      });
    });

    test('shows none itself on iOS, which shows the push', () async {
      await NotificationTrayService(
        isSupported: true,
        showsBannersItself: false,
      ).showBanner(messageId: 'fcm-1', title: 'alice', body: 'Hi');

      expect(calls, isEmpty);
    });

    test('never throws when showing fails', () async {
      answerCalls((call) async {
        throw PlatformException(code: 'notify-failed');
      });

      await expectLater(
        NotificationTrayService(isSupported: true, showsBannersItself: true)
            .showBanner(messageId: 'fcm-1', title: 'alice', body: 'Hi'),
        completes,
      );
    });

    test("answers iOS's question with the push's data", () async {
      final tray =
          NotificationTrayService(isSupported: true, showsBannersItself: false);
      Map<String, dynamic>? asked;
      tray.answerBannerQuestions((data) {
        asked = data;
        return false;
      });
      addTearDown(() => tray.answerBannerQuestions(null));

      final reply = await _askFromIos('shouldShowBanner', {'roomId': 'room-1'});

      expect(asked, {'roomId': 'room-1'});
      expect(reply, isFalse);
    });

    test('answers nothing on Android', () async {
      NotificationTrayService(isSupported: true, showsBannersItself: true)
          .answerBannerQuestions((_) => false);

      expect(await _askFromIos('shouldShowBanner', const {}), isNull);
    });
  });
}

/// Calls [method] on the Dart side of the channel, as the iOS app does, and
/// returns the answer, or null when nothing answers.
Future<Object?> _askFromIos(String method, Object? arguments) async {
  const codec = StandardMethodCodec();
  ByteData? reply;
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'bleya/notifications',
    codec.encodeMethodCall(MethodCall(method, arguments)),
    (data) => reply = data,
  );
  final answer = reply;
  if (answer == null) return null;
  return codec.decodeEnvelope(answer);
}
