import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'brand_tokens.dart';
import 'ui_tokens.dart';

class BleyaTheme {
  static const Color background = BrandTokens.background;
  static const Color foreground = BrandTokens.foreground;
  static const Color mutedForeground = BrandTokens.mutedForeground;
  static const Color primary = BrandTokens.primary;
  static const Color secondary = BrandTokens.secondary;
  static const Color accent = BrandTokens.accent;
  static const Color success = BrandTokens.success;
  static const Color error = BrandTokens.error;
  static const Color errorBorder = BrandTokens.errorBorder;
  static const Color border = BrandTokens.border;
  static const Color glassSurface = BrandTokens.glassSurface;

  static Color get primaryLight => primary.withValues(alpha: 0.1);
  static Color get primaryMedium => primary.withValues(alpha: 0.3);
  static Color get primaryDark => const Color(0xFF0052CC);

  static Color get greyLight => const Color(0xFFF5F5F5);
  static Color get greyMedium => const Color(0xFFE0E0E0);
  static Color get greyBorder => const Color(0xFFBDBDBD);
  static Color get greyText => const Color(0xFF757575);

  static Color get foreground87 => foreground.withValues(alpha: 0.87);
  static Color get foreground54 => foreground.withValues(alpha: 0.54);

  static Color get privateRoomLight => const Color(0xFFE1BEE7);
  static Color get privateRoomDark => const Color(0xFF7B1FA2);

  static const double glassOpacity = BrandTokens.glassOpacity;
  static const double glassBorderOpacity = BrandTokens.glassBorderOpacity;

  static const double radiusSmall = BrandTokens.radiusSmall;
  static const double radiusMedium = BrandTokens.radiusMedium;
  static const double radiusLarge = BrandTokens.radiusLarge;

  static const double spacingXS = BrandTokens.spacingXS;
  static const double spacingSM = BrandTokens.spacingSM;
  static const double spacingMD = BrandTokens.spacingMD;
  static const double spacingLG = BrandTokens.spacingLG;
  static const double spacingXL = BrandTokens.spacingXL;
  static const double spacing2XL = BrandTokens.spacing2XL;
  static const double spacing3XL = BrandTokens.spacing3XL;

  static const double contentPadding = BrandTokens.contentPadding;
  static const double footerPadding = BrandTokens.footerPadding;
  static const double footerBottomPadding = BrandTokens.footerBottomPadding;
  static const double cardPadding = BrandTokens.cardPadding;
  static const double iconContainerSize = BrandTokens.iconContainerSize;
  static const double buttonHeight = BrandTokens.buttonHeight;
  static const double scrollBottomPadding = BrandTokens.scrollBottomPadding;

  static List<BoxShadow> get primaryShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.35),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get glassShadow => [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  static const LinearGradient skywashGradient = BrandTokens.skywashGradient;

  /// Status and navigation bar style for the app's light screens: dark icons
  /// over the background, in iOS Dark Mode too. AppShell applies it to every
  /// screen; a page can still set its own with an AnnotatedRegion.
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: background,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static TextStyle get headingLarge => UiTokens.headingLarge(foreground);
  static TextStyle get headingMedium => UiTokens.headingMedium(foreground);
  static TextStyle get heroTagline => UiTokens.heroTagline(foreground);
  static TextStyle get featureTitle => UiTokens.featureTitle(foreground);
  static TextStyle get bodyLarge => UiTokens.bodyLarge(mutedForeground);
  static TextStyle get bodyMedium => UiTokens.bodyMedium(mutedForeground);
  static TextStyle get bodySmall => UiTokens.bodySmall(mutedForeground);
  static TextStyle get listTitle => UiTokens.listTitle(foreground);
  static TextStyle get buttonText => UiTokens.buttonText();
}
