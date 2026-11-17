import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/notification_tray_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/app_lifecycle.dart';
import '../fakes/fake_notification_tray_service.dart';

void main() {
  late FakeNotificationTrayService tray;

  setUp(() {
    tray = FakeNotificationTrayService();
  });

  /// The app's providers, with the app running.
  void startApp() {
    final container = ProviderContainer(
      overrides: [notificationTrayServiceProvider.overrideWithValue(tray)],
    );
    addTearDown(container.dispose);
    container.listen(notificationTrayClearingProvider, (_, __) {});
  }

  testWidgets('clears the notifications when the app opens', (tester) async {
    await setAppLifecycleState(tester, AppLifecycleState.resumed);

    startApp();

    expect(tray.clears, 1);
  });

  testWidgets('clears them again each time the app comes back',
      (tester) async {
    await setAppLifecycleState(tester, AppLifecycleState.resumed);
    startApp();

    // Pushes show notifications while the app is in the background.
    await setAppLifecycleState(tester, AppLifecycleState.paused);
    expect(tray.clears, 1);

    await setAppLifecycleState(tester, AppLifecycleState.resumed);
    expect(tray.clears, 2);
  });

  testWidgets('waits for an app started in the background to show',
      (tester) async {
    await setAppLifecycleState(tester, AppLifecycleState.paused);
    startApp();
    expect(tray.clears, 0);

    await setAppLifecycleState(tester, AppLifecycleState.resumed);
    expect(tray.clears, 1);
  });

  testWidgets('does nothing where the app gets no pushes', (tester) async {
    tray = FakeNotificationTrayService(isSupported: false);
    await setAppLifecycleState(tester, AppLifecycleState.resumed);
    startApp();

    await setAppLifecycleState(tester, AppLifecycleState.paused);
    await setAppLifecycleState(tester, AppLifecycleState.resumed);

    expect(tray.clears, 0);
  });
}
