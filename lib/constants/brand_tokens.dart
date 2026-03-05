import 'package:flutter/cupertino.dart';

class BrandTokens {
  static const Color background = Color(0xFFF6F7FB);
  static const Color foreground = Color(0xFF0B1220);
  static const Color mutedForeground = Color(0xFF64748B);
  static const Color primary = Color(0xFF1E6BFF);
  static const Color secondary = Color(0xFF22D3EE);
  static const Color accent = Color(0xFFFFB454);
  static const Color success = Color(0xFF059669);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBorder = Color(0xFFF87171);
  static const Color border = Color(0xFFE2E8F0);
  static const Color glassSurface = Color(0xFFFFFFFF);

  static const double glassOpacity = 0.8;
  static const double glassBorderOpacity = 0.1;

  static const double radiusSmall = 10.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;

  static const double spacingXS = 2.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 12.0;
  static const double spacingLG = 16.0;
  static const double spacingXL = 20.0;
  static const double spacing2XL = 24.0;
  static const double spacing3XL = 32.0;

  static const double contentPadding = spacingXL;
  static const double footerPadding = spacingXL;
  static const double footerBottomPadding = spacingMD;
  static const double cardPadding = spacingLG;
  static const double iconContainerSize = 44.0;
  static const double buttonHeight = 56.0;
  static const double scrollBottomPadding = 200.0;

  static const LinearGradient skywashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );
}
