import 'dart:io';

import 'package:bleya/services/app_badge_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('bleya/badge');
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

  test('sets the count through the bleya/badge channel', () async {
    await AppBadgeService(isSupported: true).setBadgeCount(3);

    expect(calls.single.method, 'setBadgeCount');
    expect(calls.single.arguments, 3);
  });

  test('0 removes the badge, and counts stop at 99 as in pushes', () async {
    final badge = AppBadgeService(isSupported: true);

    await badge.setBadgeCount(0);
    await badge.setBadgeCount(150);

    expect([for (final call in calls) call.arguments], [0, 99]);
  });

  test('does nothing on Android', () async {
    await AppBadgeService(isSupported: false).setBadgeCount(3);

    expect(calls, isEmpty);
  });

  test('keeps the badge to iPhones by default', () {
    expect(AppBadgeService().isSupported, Platform.isIOS);
  });

  test('never throws when the platform fails or has no channel', () async {
    final badge = AppBadgeService(isSupported: true);

    answerCalls((call) async {
      throw PlatformException(code: 'badge-failed');
    });
    await expectLater(badge.setBadgeCount(1), completes);

    answerCalls(null);
    await expectLater(badge.setBadgeCount(1), completes);
  });
}
