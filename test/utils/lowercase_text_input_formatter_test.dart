import 'package:bleya/utils/lowercase_text_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = LowercaseTextInputFormatter();

  test('converts uppercase input to lowercase and preserves selection', () {
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: 'TeSt_User',
        selection: TextSelection.collapsed(offset: 9),
      ),
    );

    expect(result.text, 'test_user');
    expect(result.selection.baseOffset, 9);
    expect(result.selection.extentOffset, 9);
  });

  test('leaves lowercase input unchanged', () {
    const value = TextEditingValue(
      text: 'test_user',
      selection: TextSelection.collapsed(offset: 9),
    );

    final result = formatter.formatEditUpdate(TextEditingValue.empty, value);

    expect(result, value);
  });
}
