import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the short messages the app asks the system to show
/// (`SystemMessage`), instead of showing them. Stops at the end of the test.
List<String> recordSystemMessages() {
  final messages = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('bleya/messages');
  messenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'show') {
      messages.add((call.arguments as Map)['message'] as String);
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return messages;
}
