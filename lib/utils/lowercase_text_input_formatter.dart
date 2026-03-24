import 'package:flutter/services.dart';

class LowercaseTextInputFormatter extends TextInputFormatter {
  const LowercaseTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lowercasedText = newValue.text.toLowerCase();
    if (lowercasedText == newValue.text) {
      return newValue;
    }

    return newValue.copyWith(text: lowercasedText);
  }
}
