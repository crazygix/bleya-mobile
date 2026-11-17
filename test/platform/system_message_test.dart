import 'package:bleya/platform/system_message.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/system_messages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('bleya/messages');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// The calls the app makes on the channel.
  List<MethodCall> recordCalls() {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  test('a notice asks the system for an alert, trimmed', () async {
    final calls = recordCalls();

    SystemMessage.showNotice("  Couldn't open the link.  ");
    await pumpEventQueue();

    expect(calls.single.method, 'show');
    expect(calls.single.arguments, {
      'message': "Couldn't open the link.",
      'kind': 'notice',
    });
  });

  test('a confirmation asks the system for a confirmation', () async {
    final calls = recordCalls();

    SystemMessage.showConfirmation('Passkey added.');
    await pumpEventQueue();

    expect(calls.single.arguments, {
      'message': 'Passkey added.',
      'kind': 'confirmation',
    });
  });

  test('shows nothing for a blank message', () async {
    final messages = recordSystemMessages();

    SystemMessage.showNotice('   ');
    SystemMessage.showConfirmation('');
    await pumpEventQueue();

    expect(messages, isEmpty);
  });

  test('never throws when the system fails or has no channel', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'failed');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    SystemMessage.showNotice('Hi');
    await pumpEventQueue();

    messenger.setMockMethodCallHandler(channel, null);
    SystemMessage.showConfirmation('Hi');
    await pumpEventQueue();
  });
}
