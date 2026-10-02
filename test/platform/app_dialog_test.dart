import 'package:bleya/platform/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late BuildContext homeContext;

  Future<void> showHome(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
  }) {
    navigatorKey = GlobalKey<NavigatorState>();
    return tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(platform: platform),
      home: Builder(builder: (context) {
        homeContext = context;
        return const Scaffold(body: Text('Home'));
      }),
    ));
  }

  AppDialogHandle openLoader() {
    return AppDialog.open(
      context: homeContext,
      builder: (_) => const Center(child: Text('Loading')),
    );
  }

  testWidgets('back closes the dialog, and the handle then does nothing',
      (tester) async {
    await showHome(tester);
    final loader = openLoader();
    await tester.pumpAndSettle();
    expect(find.text('Loading'), findsOneWidget);
    expect(loader.isOpen, isTrue);
    expect(loader.isOnTop, isTrue);

    // Android back.
    await tester.binding.handlePopRoute();
    expect(loader.isOpen, isFalse);

    // Its work ends while the dialog is still animating away, and again
    // once it's gone.
    loader.close();
    await tester.pumpAndSettle();
    loader.close();
    await tester.pumpAndSettle();

    expect(find.text('Loading'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('closing it on top pops it', (tester) async {
    await showHome(tester);
    final loader = openLoader();
    await tester.pumpAndSettle();

    loader.close();
    expect(loader.isOpen, isFalse);
    await tester.pumpAndSettle();

    expect(find.text('Loading'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('closing it under another screen removes only the dialog',
      (tester) async {
    await showHome(tester, platform: TargetPlatform.iOS);
    final loader = openLoader();
    await tester.pumpAndSettle();
    navigatorKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Thread')),
    ));
    await tester.pumpAndSettle();
    expect(loader.isOpen, isTrue);
    expect(loader.isOnTop, isFalse);

    loader.close();
    await tester.pumpAndSettle();

    expect(loader.isOpen, isFalse);
    expect(find.text('Thread'), findsOneWidget);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Loading'), findsNothing);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });
}
