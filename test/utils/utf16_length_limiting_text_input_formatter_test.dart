import 'package:bleya/utils/utf16_length_limiting_text_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// [text] with the cursor at its end.
TextEditingValue typed(String text, {TextRange composing = TextRange.empty}) {
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
    composing: composing,
  );
}

void main() {
  const thumbsUp = '\u{1F44D}'; // Two UTF-16 code units.
  const family = '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}'; // Eight.

  final enforced = Utf16LengthLimitingTextInputFormatter(
    10,
    maxLengthEnforcement: MaxLengthEnforcement.enforced,
  );
  final afterComposition = Utf16LengthLimitingTextInputFormatter(
    10,
    maxLengthEnforcement: MaxLengthEnforcement.truncateAfterCompositionEnds,
  );

  for (final formatter in [enforced, afterComposition]) {
    group('${formatter.maxLengthEnforcement!.name}:', () {
      test('lets text within the limit through', () {
        final value = typed('hello');
        expect(formatter.formatEditUpdate(typed('hell'), value), value);
      });

      test('a paste across the limit stops at exactly the limit', () {
        final result = formatter.formatEditUpdate(
          typed('abc'),
          typed('abc0123456789'),
        );

        expect(result.text, 'abc0123456');
        expect(result.selection, const TextSelection.collapsed(offset: 10));
      });

      test('counts UTF-16 code units, not characters', () {
        // Six characters, but twelve code units: the server counts twelve.
        final result = formatter.formatEditUpdate(
          typed(''),
          typed(thumbsUp * 6),
        );

        expect(result.text, thumbsUp * 5);
      });

      test('an emoji across the limit is dropped whole', () {
        final result = formatter.formatEditUpdate(
          typed('123456789'),
          typed('123456789$thumbsUp'),
        );

        expect(result.text, '123456789');
      });

      test('a joined emoji across the limit is dropped whole', () {
        final result = formatter.formatEditUpdate(
          typed('abcde'),
          typed('abcde$family'),
        );

        expect(result.text, 'abcde');
      });

      test('typing at the limit keeps the text as it was', () {
        final full = typed('0123456789');

        expect(formatter.formatEditUpdate(full, typed('0123456789x')), full);
      });

      group('text the app put back over the limit', () {
        final restored = typed('0123456789abcd');

        test('can be shortened', () {
          final deleted = typed('0123456789abc');

          expect(formatter.formatEditUpdate(restored, deleted), deleted);
        });

        test('is never cut', () {
          final result = formatter.formatEditUpdate(
            restored,
            const TextEditingValue(
              text: '0123456789ab_d',
              selection: TextSelection.collapsed(offset: 13),
            ),
          );

          expect(result.text, '0123456789ab_d');
        });

        test("can't get longer", () {
          expect(
            formatter.formatEditUpdate(restored, typed('0123456789abcde')),
            restored,
          );
        });
      });
    });
  }

  group('replacing a selection at the limit with longer text', () {
    const old = TextEditingValue(
      text: '0123456789',
      selection: TextSelection(baseOffset: 8, extentOffset: 10),
    );

    test('cuts it at the limit where the limit is enforced', () {
      final result = enforced.formatEditUpdate(old, typed('01234567abcd'));

      expect(result.text, '01234567ab');
    });

    test('keeps the text as it was elsewhere, as Flutter does', () {
      expect(
        afterComposition.formatEditUpdate(old, typed('01234567abcd')),
        old,
      );
    });
  });

  group('text still being composed', () {
    test('may run over until it is done, where the platform allows it', () {
      // Composing "かな" after eight characters.
      final composing = typed(
        '12345678かなか',
        composing: const TextRange(start: 8, end: 11),
      );

      expect(
        afterComposition.formatEditUpdate(
          typed('12345678か', composing: const TextRange(start: 8, end: 9)),
          composing,
        ),
        composing,
      );

      // Committing the composition cuts it at the limit.
      final committed = afterComposition.formatEditUpdate(
        composing,
        typed('12345678仮名か'),
      );
      expect(committed.text, '12345678仮名');
    });

    test("can't start at the limit", () {
      final full = typed('0123456789');

      expect(
        afterComposition.formatEditUpdate(
          full,
          typed('0123456789か', composing: const TextRange(start: 10, end: 11)),
        ),
        full,
      );
    });

    test('is cut right away where the limit is enforced', () {
      final result = enforced.formatEditUpdate(
        typed('12345678'),
        typed('12345678かなか', composing: const TextRange(start: 8, end: 11)),
      );

      expect(result.text, '12345678かな');
      expect(result.composing, const TextRange(start: 8, end: 10));
    });
  });

  test('uses the platform convention by default', () {
    // Tests run as Android, where the limit is enforced while composing.
    final formatter = Utf16LengthLimitingTextInputFormatter(2);

    final result = formatter.formatEditUpdate(
      typed(''),
      typed('かなか', composing: const TextRange(start: 0, end: 3)),
    );

    expect(result.text, 'かな');
  });

  test('the server limit holds for 2,000 code units', () {
    final formatter = Utf16LengthLimitingTextInputFormatter(2000);

    final result = formatter.formatEditUpdate(
      typed(''),
      typed('a' * 1999 + thumbsUp + 'b' * 1000),
    );

    expect(result.text, 'a' * 1999);
    expect(result.text.length, lessThanOrEqualTo(2000));
  });
}
