import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The platform reports that the app is now in [state], as iOS and Android
/// do. The binding passes through the states in between, so going from
/// resumed to paused also passes through inactive and hidden.
Future<void> setAppLifecycleState(
  WidgetTester tester,
  AppLifecycleState state,
) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.lifecycle.name,
    SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
    (_) {},
  );
  await tester.pump();
}
