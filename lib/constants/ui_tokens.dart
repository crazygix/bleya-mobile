import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../platform/ui_platform.dart';

class UiTokens {
  static String? get systemFontFamily =>
      isIosPlatform() ? '.SF Pro Text' : null;

  // Outfit ships with the app and is never downloaded, so every Outfit style
  // lives here, and each weight they use needs its file in
  // assets/google_fonts/ (Outfit-SemiBold, Outfit-Bold, Outfit-ExtraBold).
  // test/constants/outfit_fonts_test.dart checks that they all load.

  static TextStyle headingLarge(Color color) => GoogleFonts.outfit(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle headingMedium(Color color) => GoogleFonts.outfit(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: color,
      );

  static TextStyle heroTagline(Color color) => GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  static TextStyle featureTitle(Color color) => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle bodyLarge(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.normal,
        color: color,
        height: 1.5,
        fontFamily: systemFontFamily,
      );

  static TextStyle bodyMedium(Color color) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: color,
        fontFamily: systemFontFamily,
      );

  static TextStyle bodySmall(Color color) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.normal,
        color: color,
        fontFamily: systemFontFamily,
      );

  static TextStyle listTitle(Color color) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.2,
        fontFamily: systemFontFamily,
      );

  static TextStyle buttonText() => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: systemFontFamily,
      );
}
