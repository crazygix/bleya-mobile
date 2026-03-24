import 'package:bleya/platform/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('passes keyboard behavior to the material text field', (
    tester,
  ) async {
    final controller = TextEditingController();

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            controller: controller,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            enableSuggestions: false,
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.textCapitalization, TextCapitalization.none);
    expect(textField.autocorrect, false);
    expect(textField.enableSuggestions, false);
  });
}
