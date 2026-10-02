import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// Limits text to [maxLength] UTF-16 code units, the unit the server counts
/// (JavaScript's `String.length`).
///
/// Flutter's [LengthLimitingTextInputFormatter] counts user-perceived
/// characters instead, so emoji and some scripts could get past a server
/// limit. Like it, this formatter cuts only between whole characters and,
/// where the platform's convention allows it ([maxLengthEnforcement]), lets
/// text the keyboard is still composing run over until it's done.
///
/// Text can already be over the limit when the app puts it back itself, for
/// example after a failed send. Edits may shorten such text, but they can't
/// lengthen it, and it is never cut.
class Utf16LengthLimitingTextInputFormatter extends TextInputFormatter {
  Utf16LengthLimitingTextInputFormatter(
    this.maxLength, {
    this.maxLengthEnforcement,
  }) : assert(maxLength > 0);

  /// The most UTF-16 code units the text may have.
  final int maxLength;

  /// How the limit treats text being composed. Defaults to the platform's
  /// convention, as [LengthLimitingTextInputFormatter] does.
  final MaxLengthEnforcement? maxLengthEnforcement;

  /// [value] cut to the longest run of whole characters that fits in
  /// [maxLength] UTF-16 code units.
  static TextEditingValue truncate(TextEditingValue value, int maxLength) {
    var length = 0;
    for (final character in value.text.characters) {
      if (length + character.length > maxLength) break;
      length += character.length;
    }
    final truncated = value.text.substring(0, length);
    return TextEditingValue(
      text: truncated,
      selection: value.selection.copyWith(
        baseOffset: math.min(value.selection.start, truncated.length),
        extentOffset: math.min(value.selection.end, truncated.length),
      ),
      composing: !value.composing.isCollapsed &&
              truncated.length > value.composing.start
          ? TextRange(
              start: value.composing.start,
              end: math.min(value.composing.end, truncated.length),
            )
          : TextRange.empty,
    );
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= maxLength) return newValue;

    final oldLength = oldValue.text.length;
    switch (maxLengthEnforcement ??
        LengthLimitingTextInputFormatter.getDefaultMaxLengthEnforcement()) {
      case MaxLengthEnforcement.none:
        return newValue;
      case MaxLengthEnforcement.enforced:
        // Only text the app put back can be over the limit already.
        if (oldLength > maxLength) return _shrinkOnly(oldValue, newValue);
        // Typing at the limit changes nothing.
        if (oldLength == maxLength && oldValue.selection.isCollapsed) {
          return oldValue;
        }
        return truncate(newValue, maxLength);
      case MaxLengthEnforcement.truncateAfterCompositionEnds:
        if (!oldValue.composing.isValid) {
          // Over the limit with nothing being composed: the app put it back.
          if (oldLength > maxLength) return _shrinkOnly(oldValue, newValue);
          // At the limit, nothing more can be typed or composed.
          if (oldLength == maxLength) return oldValue;
        }
        // Text being composed is cut once it's done.
        if (newValue.composing.isValid) return newValue;
        return truncate(newValue, maxLength);
    }
  }

  /// Text that is already over the limit may get shorter, but not longer.
  static TextEditingValue _shrinkOnly(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.text.length <= oldValue.text.length ? newValue : oldValue;
  }
}
