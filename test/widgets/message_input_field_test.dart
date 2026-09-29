import 'package:bleya/widgets/message_input_field.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
