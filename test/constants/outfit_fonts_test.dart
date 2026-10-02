import 'dart:io';

import 'package:bleya/constants/theme.dart';
import 'package:bleya/constants/ui_tokens.dart';
import 'package:bleya/main.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Every Outfit style in UiTokens. A new one belongs here too, so its weight
/// is checked; the count test below asks for it.
final _outfitStyles = <String, TextStyle Function(Color)>{
  'headingLarge': UiTokens.headingLarge,
  'headingMedium': UiTokens.headingMedium,
  'heroTagline': UiTokens.heroTagline,
  'featureTitle': UiTokens.featureTitle,
};

/// The bundled files: the same bytes Google Fonts serves for these weights
/// (google_fonts names each file by its SHA-256).
const _bundledFonts = {
  'Outfit-SemiBold.ttf':
      '3b9c6753e282f674c8acfa64c24eba2057c1c123830595cba4e3adbf8c5e9f24',
  'Outfit-Bold.ttf':
      '8d3a851bbdbcef9f4e7bbee2ffdb74271a80d745c40dbb68888e5759d5976477',
  'Outfit-ExtraBold.ttf':
      '95f91a67031e82a8ddcdbac44fcf4fff74e58f1e017f1759f90087390922f14a',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(useBundledFonts);

  test('fonts are never downloaded', () {
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });

  test('every Outfit style loads from the bundled files', () async {
    for (final style in _outfitStyles.values) {
      style(BleyaTheme.foreground);
    }

    // Fails if a weight in use has no bundled file, or a misnamed one.
    await expectLater(GoogleFonts.pendingFonts(), completes);
  });

  test('the bundled files are the expected Outfit fonts', () async {
    for (final MapEntry(key: name, value: sha256Hash)
        in _bundledFonts.entries) {
      final bytes = await rootBundle.load('assets/google_fonts/$name');
      expect(
        sha256.convert(bytes.buffer.asUint8List()).toString(),
        sha256Hash,
        reason: name,
      );
    }
  });

  test('the check above covers every Outfit style in UiTokens', () {
    final source = File('lib/constants/ui_tokens.dart').readAsStringSync();

    expect(
      RegExp(r'GoogleFonts\.outfit\(').allMatches(source),
      hasLength(_outfitStyles.length),
    );
  });

  test('Outfit styles are made only in UiTokens', () {
    final elsewhere = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('constants/ui_tokens.dart'))
        .where((file) => file.readAsStringSync().contains('GoogleFonts.outfit'))
        .map((file) => file.path);

    expect(elsewhere, isEmpty);
  });

  test("the font's licence ships with the app and is listed", () async {
    final license = await rootBundle.loadString(outfitLicenseAsset);
    expect(license, contains('SIL OPEN FONT LICENSE'));

    final entries = await LicenseRegistry.licenses.toList();
    final outfit = entries.where((entry) => entry.packages.contains('Outfit'));
    expect(outfit, hasLength(1));
    expect(
      outfit.single.paragraphs.map((paragraph) => paragraph.text).join('\n'),
      contains('SIL OPEN FONT LICENSE'),
    );
  });
}
