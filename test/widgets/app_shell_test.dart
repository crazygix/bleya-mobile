import 'package:bleya/constants/theme.dart';
import 'package:bleya/providers/connectivity_provider.dart';
import 'package:bleya/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the device's connection.
final _online = StateProvider<bool>((ref) => true);

/// A screen with some state of its own: how often its button was tapped.
class _CounterPage extends StatefulWidget {
  const _CounterPage();

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: TextButton(
          onPressed: () => setState(() => _taps++),
          child: Text('Tapped $_taps times'),
        ),
      ),
    );
  }
}

void main() {
  // A notched iPhone: a 47 pt status bar.
  const statusBarHeight = 47.0;
  const offlineText = 'No internet connection';

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        isOnlineProvider.overrideWith((ref) => ref.watch(_online)),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> setOnline(WidgetTester tester, bool online) async {
    container.read(_online.notifier).state = online;
    await tester.pump();
  }

  Future<void> showApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: statusBarHeight * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => AppShell(child: child!),
          home: const _CounterPage(),
        ),
      ),
    );
  }

  /// The top inset the screen is given.
  double pageTopInset(WidgetTester tester) {
    return MediaQuery.paddingOf(tester.element(find.byType(_CounterPage))).top;
  }

  testWidgets('online, there is no strip and the screen keeps the inset',
      (tester) async {
    await showApp(tester);

    expect(find.text(offlineText), findsNothing);
    expect(pageTopInset(tester), statusBarHeight);
    expect(tester.getTopLeft(find.byType(_CounterPage)).dy, 0);
  });

  testWidgets(
      'offline, the strip sits below the status bar and moves the '
      'screen down', (tester) async {
    await showApp(tester);

    await setOnline(tester, false);

    final strip = find.ancestor(
      of: find.text(offlineText),
      matching: find.byType(Material),
    );
    expect(tester.getTopLeft(strip).dy, 0);
    expect(
      tester.getTopLeft(find.text(offlineText)).dy,
      greaterThanOrEqualTo(statusBarHeight),
    );
    // The screen starts below the strip, so nothing hides behind it.
    expect(
      tester.getTopLeft(find.byType(_CounterPage)).dy,
      tester.getBottomLeft(strip).dy,
    );
    expect(pageTopInset(tester), 0);

    await setOnline(tester, true);

    expect(find.text(offlineText), findsNothing);
    expect(pageTopInset(tester), statusBarHeight);
  });

  testWidgets("the strip's text is plain, not the unstyled fallback",
      (tester) async {
    await showApp(tester);

    await setOnline(tester, false);

    final text = tester.renderObject<RenderParagraph>(find.text(offlineText));
    expect(
      text.text.style?.decoration,
      anyOf(isNull, TextDecoration.none),
    );
    expect(text.text.style?.color, Colors.white);
  });

  testWidgets('a screen keeps its state while the connection comes and goes',
      (tester) async {
    await showApp(tester);
    await tester.tap(find.text('Tapped 0 times'));
    await tester.pump();
    await tester.tap(find.text('Tapped 1 times'));
    await tester.pump();

    await setOnline(tester, false);
    await setOnline(tester, true);
    await setOnline(tester, false);

    expect(find.text('Tapped 2 times'), findsOneWidget);
    await tester.tap(find.text('Tapped 2 times'));
    await tester.pump();
    expect(find.text('Tapped 3 times'), findsOneWidget);
  });

  testWidgets('the status bar has dark icons, and light ones over the strip',
      (tester) async {
    await showApp(tester);
    await tester.pump();

    expect(
      SystemChrome.latestStyle?.statusBarIconBrightness,
      Brightness.dark,
    );
    expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.light);

    await setOnline(tester, false);
    await tester.pump();

    expect(
      SystemChrome.latestStyle?.statusBarIconBrightness,
      Brightness.light,
    );
    expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.dark);
    expect(
      SystemChrome.latestStyle?.systemNavigationBarColor,
      BleyaTheme.background,
    );

    await setOnline(tester, true);
    await tester.pump();

    expect(
      SystemChrome.latestStyle?.statusBarIconBrightness,
      Brightness.dark,
    );
  });
}
