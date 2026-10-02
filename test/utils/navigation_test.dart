import 'dart:async';

import 'package:bleya/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'showHomeAsOnlyRoute leaves the chat list as the only screen, so back '
      'leaves the app', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      routes: {
        '/': (_) => const Text('Intro'),
        '/home': (_) => const Text('Chats'),
      },
    ));
    // Signing in happens on screens pushed over the intro.
    unawaited(navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('Sign in')),
    ));
    unawaited(navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('Username')),
    ));
    await tester.pumpAndSettle();

    unawaited(showHomeAsOnlyRoute(navigator.currentState!));
    await tester.pumpAndSettle();

    expect(find.text('Chats'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);

    // Android back: nothing to go back to, so the app closes.
    expect(await navigator.currentState!.maybePop(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Intro'), findsNothing);
  });
}
