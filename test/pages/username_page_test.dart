import 'dart:async';

import 'package:bleya/controllers/username_controller.dart';
import 'package:bleya/pages/username_page.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/controller_providers.dart';
import 'package:bleya/services/auth_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks.dart';

/// Counts sign-outs instead of signing out.
class _RecordingAuthManager extends AuthManager {
  _RecordingAuthManager(super.ref);

  int logouts = 0;

  @override
  Future<void> logout({bool accountDeleted = false}) async {
    logouts++;
  }
}

void main() {
  late _RecordingAuthManager authManager;

  testWidgets('system back on the username page signs out instead of leaving',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authManagerProvider.overrideWith(
          (ref) => authManager = _RecordingAuthManager(ref),
        ),
        usernameControllerProvider.overrideWith(
          (ref) => UsernameController(
            MockCheckUsernameUseCase(),
            MockSetUsernameUseCase(),
            MockUploadProfileImageUseCase(),
            () async => false,
          ),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigator,
        home: const Text('Intro'),
      ),
    ));
    // A new account picks a username after signing in on the intro.
    unawaited(navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const UsernamePage()),
    ));
    await tester.pumpAndSettle();

    // Android back.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(authManager.logouts, 1);
    // Signing out shows the intro; the page doesn't uncover it by itself.
    expect(find.text('Pick your handle'), findsOneWidget);
  });
}
