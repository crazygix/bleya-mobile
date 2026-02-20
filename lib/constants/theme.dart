import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class BleyaTheme {
  // ========================================
  // PRODUCT POSITIONING
  // ========================================
  // Bleya is built for solo travelers first.
  // Other travelers are welcome, but product defaults and messaging should
  // prioritize solo-traveler confidence, safety, and social discovery.

  // ========================================
  // CAFÉ COAST COLOR PALETTE
  // ========================================

  // BASE (Ice White - #F6F7FB)
  // Used for 90% of background. Slightly blue-tinted to feel "cooler" and premium.
  static const Color background = Color(0xFFF6F7FB);

  // TYPOGRAPHY (Deep Ocean Blue - #0B1220)
  // NEVER use pure black (#000000). This deep navy provides readability while staying "organic."
  static const Color foreground = Color(0xFF0B1220);
  static const Color mutedForeground =
      Color(0xFF64748B); // Muted text for placeholders, helper text

  // PRIMARY ACTION (Coat Blue - #1E6BFF)
  // Bright Mediterranean blue for main buttons and links. Use sparingly (20% rule).
  static const Color primary = Color(0xFF1E6BFF);

  // SECONDARY (Aqua Tint - #22D3EE)
  // Complementary to primary in gradients. Part of liquid background orbs.
  static const Color secondary = Color(0xFF22D3EE);

  // ACCENTS (Soft Sand - #FFB454 / Apricot)
  // Used for highlights, success states, or active orbs. Provides the "warmth."
  static const Color accent = Color(0xFFFFB454);
  static const Color success =
      Color(0xFF059669); // Darker emerald green for validations
  static const Color error =
      Color(0xFFEF4444); // Error red (shade500 equivalent)
  static const Color errorBorder =
      Color(0xFFF87171); // Error border (shade400 equivalent)

  // Glass & Borders
  static const Color border =
      Color(0xFFE2E8F0); // Hairline dividers, glass borders
  static const Color glassSurface = Color(0xFFFFFFFF); // White for glass effect

  // Primary color variants (for chat bubbles, active states)
  static Color get primaryLight => primary.withValues(alpha: 0.1); // ~blue[50]
  static Color get primaryMedium =>
      primary.withValues(alpha: 0.3); // ~blue[200]
  static Color get primaryDark => Color(0xFF0052CC); // ~blue[700]

  // Grey variants (for backgrounds, dividers, inactive states)
  static Color get greyLight => Color(0xFFF5F5F5); // ~grey[50]
  static Color get greyMedium => Color(0xFFE0E0E0); // ~grey[200]
  static Color get greyBorder => Color(0xFFBDBDBD); // ~grey[300]
  static Color get greyText => Color(0xFF757575); // ~grey[600]

  // Text opacity variants
  static Color get foreground87 =>
      foreground.withValues(alpha: 0.87); // ~black87
  static Color get foreground54 =>
      foreground.withValues(alpha: 0.54); // ~black54

  // Private room color (purple variant)
  static Color get privateRoomLight => Color(0xFFE1BEE7); // ~purple[100]
  static Color get privateRoomDark => Color(0xFF7B1FA2); // ~purple[700]

  // Glass opacity values
  // Glassmorphism: Semi-transparent white fill for frosted glass effect
  static const double glassOpacity = 0.8; // 80% opacity for glass surfaces
  static const double glassBorderOpacity =
      0.1; // Subtle border for inner glow effect

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

  // Gradients
  static const LinearGradient skywashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  // ========================================
  // ICONOGRAPHY - Hybrid Icon Strategy
  // ========================================
  //
  // This design system uses a hybrid approach balancing HIG compliance with brand needs:
  //
  // SYSTEM ACTIONS (CupertinoIcons - SF Symbols - HIG Compliant):
  //   - Navigation icons: chevron_left, chevron_right, xmark, etc.
  //   - Common actions: settings, share, search, heart, bookmark, etc.
  //   - System buttons and controls
  //   - Standard UI elements
  //   Usage: CupertinoIcons.icon_name
  //   Size: 20-28px depending on context
  //   Color: BleyaTheme.mutedForeground (default), BleyaTheme.primary (active)
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
  // COMMON ICONS:
  //   - Back: CupertinoIcons.chevron_left (size: 28)
  //   - Close: CupertinoIcons.xmark
  //   - Settings: CupertinoIcons.settings
  //   - Share: CupertinoIcons.share
  //   - Search: CupertinoIcons.search
  //   - Heart: CupertinoIcons.heart / heart_fill
  //   - Camera: CupertinoIcons.camera / camera_fill
  //   - Phone: CupertinoIcons.phone
  //   - Shield: CupertinoIcons.shield (for privacy/security)
  //
  // This approach ensures:
  //   1. HIG compliance for native iOS feel (SF Symbols for system actions)
  //   2. Brand flexibility when needed (custom icons for unique features)
  //   3. Consistency across all screens
  //
  // ========================================

  // ========================================
  // TYPOGRAPHY - Hybrid Font Strategy
  // ========================================
  //
  // This design system uses a hybrid approach balancing HIG compliance with brand identity:
  //
  // BRAND MOMENTS (Outfit - Custom Font via Google Fonts):
  //   - Main brand name/logo text
  //   - Hero headlines and taglines
  //   - Feature titles and prominent headings (page titles)
  //   - Marketing/promotional text
  //   Usage: GoogleFonts.outfit() or BleyaTheme.headingLarge/headingMedium
  //   Weight: FontWeight.w800 (extra bold)
  //   Examples: "What's your number?", "Confirm it's you", "How should we call you?"
  //   Note: Follow sentence case (only first letter capitalized) per Bleya Voice Framework
  //
  // UI ELEMENTS (SF Pro - HIG Compliant):
  //   - Body text and descriptions
  //   - Button labels
  //   - Navigation text
  //   - Legal/disclaimer text
  //   - Form labels and input text
  //   - General UI copy
  //   Usage: BleyaTheme.bodyLarge/bodyMedium/bodySmall/buttonText
  //   Weight: FontWeight.normal (body), FontWeight.bold (buttons)
  //   Examples: "We'll send you a code. Quick and secure.", "This is how friends will find you."
  //
  // FONT SIZES:
  //   - headingLarge: 44px (hero moments)
  //   - headingMedium: 34px (page titles)
  //   - bodyLarge: 17px (descriptions, main body)
  //   - bodyMedium: 16px (secondary text)
  //   - bodySmall: 13px (captions, hints)
  //   - buttonText: 18px (button labels)
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

  // List item title style (for chat/room names in lists)
  static TextStyle get listTitle => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: foreground,
        letterSpacing: -0.2,
        fontFamily: '.SF Pro Text', // SF Pro on iOS
      );

  // Button text style (SF Pro - HIG compliant)
  static TextStyle get buttonText => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: '.SF Pro Text', // SF Pro on iOS
      );

  // ========================================
  // IMPLEMENTATION GUIDELINES
  // ========================================
  //
  // When implementing new features or screens, follow these guidelines.
  // Reference: "implement per design system" or "follow design system"
  //
  // PAGE STRUCTURE:
  //   - Transparent status bar (see existing pages)
  //   - Back button positioned at top using MediaQuery.padding.top
  //   - Liquid glass background with 2-3 blurry orbs (primary + accent colors)
  //   - SafeArea(bottom: false) for main content
  //   - Use BleyaTheme constants for spacing, padding, colors
  //
  // GLASSMORPHISM:
  //   - Backdrop blur: 20px+
  //   - Semi-transparent white: glassSurface.withValues(alpha: glassOpacity)
  //   - Inner glow: 1px white border (top/left)
  //   - Shadow: glassShadow
  //
  // MOTION:
  //   - Staggered entrance: 0.05s delay between elements
  //   - Button "squish": scale 0.95 on press
  //   - Weightless transitions: orbs persist, content animates
  //
  // ========================================
}
