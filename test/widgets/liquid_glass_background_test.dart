import 'package:bleya/widgets/liquid_glass_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder underBackground(Type type) {
    return find.descendant(
      of: find.byType(LiquidGlassBackground),
      matching: find.byType(type),
    );
  }

  /// A page laid out as the app's are: the background first in a Stack.
  Widget page() {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            const LiquidGlassBackground(),
            SafeArea(child: Text('Page')),
          ],
        ),
      ),
    );
  }

  testWidgets('blurs nothing', (tester) async {
    await tester.pumpWidget(page());

    expect(underBackground(BackdropFilter), findsNothing);
    expect(underBackground(ImageFiltered), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fills the page', (tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(page());

    expect(
      tester.getRect(find.byType(LiquidGlassBackground)),
      const Rect.fromLTWH(0, 0, 390, 844),
    );
  });

  testWidgets('fills whatever box it is given', (tester) async {
    await tester.pumpWidget(
      const Center(
        child: SizedBox(
          width: 300,
          height: 500,
          child: LiquidGlassBackground(),
        ),
      ),
    );

    expect(tester.getSize(find.byType(LiquidGlassBackground)),
        const Size(300, 500));
  });

  testWidgets('paints the three orbs where the design puts them, once',
      (tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(page());

    final painter = tester.renderObject<RenderCustomPaint>(
      underBackground(CustomPaint),
    );
    expect(
      painter,
      paints
        ..clipRect(rect: const Rect.fromLTWH(0, 0, 390, 844))
        // Blue, top right.
        ..circle(x: 390 - 190, y: 170, radius: 823)
        // Aqua, bottom left.
        ..circle(x: 140, y: 844 - 160, radius: 646)
        // Sand, centre right.
        ..circle(x: 390 - 145, y: 425, radius: 555),
    );
    // Cached in its own layer, never repainted with the page.
    expect(underBackground(RepaintBoundary), findsOneWidget);
    expect(painter.painter!.shouldRepaint(painter.painter!), isFalse);
  });
}
