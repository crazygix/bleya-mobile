import 'package:bleya/widgets/message_input_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sixty short lines: far more than the box shows at once.
final _sixtyLines = List.generate(60, (i) => 'Line ${i + 1}').join('\n');

void main() {
  group('restoreUnsentDraft', () {
    test('puts the unsent text back into an empty input', () {
      final controller = TextEditingController();

      restoreUnsentDraft(controller, 'hello');

      expect(controller.text, 'hello');
      expect(controller.selection.baseOffset, 5);
    });

    test('keeps what was typed since, on the next line', () {
      final controller = TextEditingController(text: 'and more');

      restoreUnsentDraft(controller, 'hello');

      expect(controller.text, 'hello\nand more');
    });
  });

  group('with the keyboard up on a phone', () {
    // A 390 x 844 pt phone with a 336 pt keyboard.
    const screenHeight = 844.0;
    const keyboardHeight = 336.0;

    late TextEditingController controller;
    late int sends;

    setUp(() {
      controller = TextEditingController();
      sends = 0;
    });

    tearDown(() => controller.dispose());

    Future<void> showChat(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(390 * 3, screenHeight * 3)
        ..devicePixelRatio = 3
        ..viewInsets = const FakeViewPadding(bottom: keyboardHeight * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(child: ListView(children: const [Text('History')])),
                MessageInputField(
                  controller: controller,
                  onSend: () => sends++,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Finder sendButton() => find.byIcon(CupertinoIcons.arrow_up);

    /// Lets an error toast go away, so no timer outlives the test.
    Future<void> waitForToasts(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 4));
    }

    testWidgets('long text grows to six lines, then scrolls inside the box',
        (tester) async {
      await showChat(tester);

      await tester.enterText(find.byType(TextField), _sixtyLines);
      await tester.pump();

      expect(tester.takeException(), isNull);
      final editable =
          tester.allRenderObjects.whereType<RenderEditable>().single;
      expect(
        editable.size.height,
        moreOrLessEquals(
          MessageInputField.maxVisibleLines * editable.preferredLineHeight,
        ),
      );
      expect(
        tester.getSize(find.byType(TextField)).height,
        lessThanOrEqualTo(screenHeight / 4),
      );
      expect(controller.text, _sixtyLines);
    });

    testWidgets('send stays above the keyboard and sends', (tester) async {
      await showChat(tester);

      await tester.enterText(find.byType(TextField), _sixtyLines);
      await tester.pump();

      expect(
        tester.getRect(sendButton()).bottom,
        lessThanOrEqualTo(screenHeight - keyboardHeight),
      );
      await tester.tap(sendButton());
      expect(sends, 1);
    });

    testWidgets('at the largest text size the box keeps to a quarter screen',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await showChat(tester);

      await tester.enterText(find.byType(TextField), _sixtyLines);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TextField)).height,
        lessThanOrEqualTo(screenHeight / 4),
      );
      expect(
        tester.getRect(sendButton()).bottom,
        lessThanOrEqualTo(screenHeight - keyboardHeight),
      );
    });

    testWidgets('a paste stops at 2,000 characters, which send as they are',
        (tester) async {
      await showChat(tester);

      await tester.enterText(find.byType(TextField), 'x' * 3000);
      await tester.pump();

      expect(controller.text, 'x' * MessageInputField.maxMessageLength);
      await tester.tap(sendButton());
      expect(sends, 1);
      expect(find.text(MessageInputField.tooLongMessage), findsNothing);
    });

    testWidgets('a draft put back over the limit says so instead of sending',
        (tester) async {
      await showChat(tester);
      await tester.enterText(find.byType(TextField), 'b' * 15);
      await tester.pump();

      // A failed send of a long message puts it back before the new text.
      restoreUnsentDraft(controller, 'a' * 1990);
      await tester.pump();
      expect(controller.text.length, 2006);

      await tester.tap(sendButton());
      await tester.pump();

      expect(sends, 0);
      expect(find.text(MessageInputField.tooLongMessage), findsOneWidget);
      await waitForToasts(tester);

      // Shortened to the limit, it sends.
      await tester.enterText(
        find.byType(TextField),
        controller.text.substring(0, MessageInputField.maxMessageLength),
      );
      await tester.pump();
      await tester.tap(sendButton());
      expect(sends, 1);
    });

    testWidgets(
        'the limit counts the text that is sent, without spaces '
        'around it', (tester) async {
      await showChat(tester);
      restoreUnsentDraft(
        controller,
        '  ${'a' * MessageInputField.maxMessageLength}\n\n',
      );
      await tester.pump();

      await tester.tap(sendButton());

      expect(sends, 1);
    });
  });
}
