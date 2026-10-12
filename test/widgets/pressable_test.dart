import 'package:bleya/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    VoidCallback? onTap,
    Widget child = const SizedBox(width: 200, height: 60),
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const SizedBox(height: 100),
              Center(child: Pressable(onTap: onTap, child: child)),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
  }

  double scale(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(Pressable),
        matching: find.byType(Transform),
      ),
    );
    // The horizontal scale; the vertical one is the same.
    return transform.transform.storage[0];
  }

  double opacity(WidgetTester tester) {
    return tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(Pressable),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
  }

  testWidgets('holding a finger on it shrinks and dims it, release restores',
      (tester) async {
    await show(tester, onTap: () {});

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    // Past the delay that tells a tap from the start of a scroll.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(scale(tester), closeTo(0.97, 0.001));
    expect(opacity(tester), closeTo(0.75, 0.001));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(tester), 1);
    expect(opacity(tester), 1);
  });

  testWidgets('a quick tap taps and still shows the whole press',
      (tester) async {
    var taps = 0;
    await show(tester, onTap: () => taps++);

    await tester.tap(find.byType(Pressable));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    expect(taps, 1);
    expect(scale(tester), closeTo(0.97, 0.001));

    await tester.pumpAndSettle();
    expect(scale(tester), 1);
  });

  testWidgets('scrolling the list shows no press and taps nothing',
      (tester) async {
    var taps = 0;
    await show(tester, onTap: () => taps++);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(tester), 1);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(scale(tester), 1);
  });

  testWidgets('without onTap it shows no press and is not a button',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester, child: const Text('Joining…'));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(scale(tester), 1);
    expect(opacity(tester), 1);
    await gesture.up();

    expect(
      tester.getSemantics(find.text('Joining…')),
      isNot(matchesSemantics(isButton: true)),
    );
    semantics.dispose();
  });

  testWidgets('the content keeps its state through a press', (tester) async {
    await show(tester, onTap: () {}, child: const _Counter());

    await tester.tap(find.text('0'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    // Pressed and released again: the count isn't reset.
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });
}

/// Counts its own taps, which a rebuilt-from-scratch child would forget.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _count++),
      child: SizedBox(width: 200, height: 60, child: Text('$_count')),
    );
  }
}
