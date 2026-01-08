import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bleya Design System - Light Mode
/// A light, premium, and airy visual style inspired by "golden hour on the Mediterranean"
class BleyaTheme {
  // Background
  static const Color background = Color(0xFFF6F7FB); // Off-white/ice

  // Text Colors
  static const Color foreground = Color(0xFF0B1220); // Dark Charcoal
  static const Color mutedForeground = Color(0xFF556274); // Slate gray

  // Brand Colors (20% rule - use sparingly)
  static const Color primary = Color(0xFF1E6BFF); // Coat Blue
  static const Color secondary = Color(0xFF22D3EE); // Aqua Tint
  static const Color accent = Color(0xFFFFB454); // Apricot
  static const Color success = Color(0xFF34D399); // Leaf

  // Glass & Borders
  static const Color border = Color(0xFFE6EAF2); // Light border
  static const Color glassSurface = Color(0xFFFFFFFF); // White for glass effect

  // Glass opacity values
  static const double glassOpacity = 0.82;
  static const double glassBorderOpacity = 0.1;

  // Border radius - Aligned with Apple's Human Interface Guidelines
  // Buttons: 10px (HIG standard for interactive elements)
  // Cards/Containers: 16px (HIG standard for content containers)
  // Large containers: 20px (HIG standard for large surfaces)
  static const double radiusSmall =
      10.0; // For buttons and small interactive elements
  static const double radiusMedium = 16.0; // For cards and content containers
  static const double radiusLarge = 20.0; // For large containers and surfaces

  // Spacing - Aligned with Apple's Human Interface Guidelines
  // Standard spacing scale following HIG recommendations
  static const double spacingXS = 2.0; // Extra small spacing
  static const double spacingSM = 8.0; // Small spacing
  static const double spacingMD = 12.0; // Medium spacing
  static const double spacingLG = 16.0; // Large spacing
  static const double spacingXL =
      20.0; // Extra large spacing (HIG standard horizontal padding)
  static const double spacing2XL = 24.0; // 2X large spacing
  static const double spacing3XL = 32.0; // 3X large spacing

  // Component-specific spacing
  static const double contentPadding =
      spacingXL; // 20px - HIG standard horizontal padding
  static const double footerPadding =
      spacingXL; // 20px - Footer horizontal padding
  static const double footerBottomPadding =
      spacingMD; // 12px - Footer bottom padding
  static const double cardPadding = spacingLG; // 16px - Card internal padding
  static const double iconContainerSize =
      44.0; // 44px - HIG minimum touch target
  static const double buttonHeight = 56.0; // 56px - Button height
  static const double scrollBottomPadding = 200.0; // Space reserved for footer

  // Shadows
  static List<BoxShadow> get primaryShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.35),
          blurRadius: 20,
          offset: Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get glassShadow => [
        BoxShadow(
          color: Color(0xFF000000).withValues(alpha: 0.04),
          blurRadius: 12,
          offset: Offset(0, 2),
        ),
      ];

  // Gradient
  static const LinearGradient skywashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  // ========================================
  // Iconography - Hybrid Icon Strategy
  // ========================================
  //
  // This design system uses a hybrid approach balancing HIG compliance with brand needs:
  //
  // SYSTEM ACTIONS (CupertinoIcons - SF Symbols - HIG Compliant):
  //   - Navigation icons (back, forward, close, etc.)
  //   - Common actions (settings, share, search, etc.)
  //   - System buttons and controls
  //   - Standard UI elements
  //   Usage: CupertinoIcons.icon_name
  //
  // BRAND-SPECIFIC FEATURES (Custom Icons - When Needed):
  //   - Unique brand features that don't have SF Symbol equivalents
  //   - Highly distinctive brand elements
  //   - Should still follow HIG principles (simple, clear, consistent)
  //
  // Apple HIG Icon Principles:
  //   1. Use SF Symbols (CupertinoIcons) for system actions
  //   2. Keep icons simple, clear, and recognizable at small sizes
  //   3. Maintain consistent size, stroke weight, and perspective
  //   4. Avoid text within icons
  //   5. Ensure icons are legible and accessible
  //
  // This approach ensures:
  //   1. HIG compliance for native iOS feel (SF Symbols for system actions)
  //   2. Brand flexibility when needed (custom icons for unique features)
  //   3. Consistency across all screens
  //
  // ========================================

  // ========================================
  // Typography - Hybrid Font Strategy
  // ========================================
  //
  // This design system uses a hybrid approach balancing HIG compliance with brand identity:
  //
  // BRAND MOMENTS (Outfit - Custom Font):
  //   - Main brand name/logo text
  //   - Hero headlines and taglines
  //   - Feature titles and prominent headings
  //   - Marketing/promotional text
  //   Usage: GoogleFonts.outfit() or BleyaTheme.headingLarge/headingMedium
  //
  // UI ELEMENTS (SF Pro - HIG Compliant):
  //   - Body text and descriptions
  //   - Button labels
  //   - Navigation text
  //   - Legal/disclaimer text
  //   - Form labels and input text
  //   - General UI copy
  //   Usage: BleyaTheme.bodyLarge/bodyMedium/bodySmall/buttonText
  //
  // This approach ensures:
  //   1. HIG compliance for native iOS feel (SF Pro for UI)
  //   2. Brand differentiation (Outfit for brand moments)
  //   3. Consistency across all screens
  //
  // ========================================

  // Brand Typography (Outfit for brand moments)
  static TextStyle get headingLarge => GoogleFonts.outfit(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: foreground,
      );

  static TextStyle get headingMedium => GoogleFonts.outfit(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: foreground,
      );

  // UI Typography (SF Pro system font - HIG compliant)
  // Uses system font which is SF Pro on iOS
  static TextStyle get bodyLarge => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.normal,
        color: mutedForeground,
        height: 1.5,
        fontFamily: '.SF Pro Text', // SF Pro on iOS
      );

  static TextStyle get bodyMedium => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: mutedForeground,
        fontFamily: '.SF Pro Text', // SF Pro on iOS
      );

  static TextStyle get bodySmall => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.normal,
        color: mutedForeground,
        fontFamily: '.SF Pro Text', // SF Pro on iOS
      );

  // Button text style (SF Pro - HIG compliant)
  static TextStyle get buttonText => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: '.SF Pro Text', // SF Pro on iOS
      );
}
