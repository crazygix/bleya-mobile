import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bleya Design System - "Café Coast" Brand Bible
/// 
/// This is the complete Brand Bible for the Flutter team to follow.
/// It defines not just colors, but the emotional response the app should trigger.
///
/// ========================================
/// 1. THE CORE VIBE: "THE GOLDEN HOUR"
/// ========================================
///
/// THE FEELING:
/// Clean, optimistic, and weightless. It should feel like sitting at a beachside
/// cafe at 5:00 PM—everything is bathed in soft, warm light.
///
/// THE ANTI-VIBE:
/// This is NOT a "Nightlife" app. There are NO:
/// - Neon purples
/// - Pitch blacks
/// - Aggressive high-contrast shadows
/// - Dark modes (for now)
/// - Harsh, saturated colors
///
/// ========================================
/// 2. THE COLOR PALETTE: "CAFÉ COAST"
/// ========================================
///
/// We use a sophisticated, low-contrast palette to keep the eye relaxed:
///
/// BASE (Ice White - #F6F7FB):
///   - Used for 90% of the background
///   - Slightly blue-tinted to feel "cooler" and more premium than pure white
///   - This is the foundation that makes everything feel weightless
///
/// TYPOGRAPHY (Deep Ocean Blue - #0B1220):
///   - We NEVER use pure black (#000000) for text
///   - This deep navy provides high readability while staying "organic"
///   - Creates warmth even in text
///
/// ACCENTS (Soft Sand - #FFB454 / Apricot):
///   - Used for highlights, success states, or active orbs
///   - Provides the "warmth" in the palette
///   - Part of liquid background orbs
///
/// PRIMARY ACTION (Coat Blue - #1E6BFF):
///   - A bright, Mediterranean blue for main buttons and links
///   - Use sparingly (20% rule - not more than 20% of screen)
///   - Part of liquid background orbs
///
/// SECONDARY (Aqua Tint - #22D3EE):
///   - Complementary to primary in gradients
///   - Part of liquid background orbs
///   - Creates the "skywash" gradient effect
///
/// ========================================
/// 3. VISUAL LANGUAGE: "FROSTED GLASS"
/// ========================================
///
/// This is the most critical part for engineers to replicate:
///
/// LIQUID BACKGROUNDS:
///   - Instead of static color, background has 2-3 large, blurry "orbs"
///   - Colors: Apricot (#FFB454) and Blue (#1E6BFF, #22D3EE)
///   - These orbs should slowly pulse or drift (makes app feel "alive")
///   - Top-right orb: 500x500, primary color (Coat Blue), alpha 0.06, blur 120px
///   - Bottom-left orb: 400x400, accent color (Apricot/Soft Sand), alpha 0.05, blur 100px
///
/// GLASSMORPHISM:
///   - UI cards use backdrop-blur (20px+)
///   - Semi-transparent white fill: bg-white/70 (glassOpacity: 0.82)
///   - Creates depth without heaviness
///
/// INNER GLOW:
///   - Every "glass" card should have a subtle 1px white border (top/left)
///   - Simulates a light source hitting the edge of the glass
///   - Creates the "frosted" effect
///
/// ========================================
/// 4. TONE OF VOICE & MESSAGING
/// ========================================
///
/// Bleya Voice Framework: Move away from "system-speak" (Utility) toward "social-speak" (Connection).
/// The text should sound like a knowledgeable, chill friend—someone who knows the best spots
/// but isn't a snob about it.
///
/// THE "GOLDEN HOUR" TONE:
///   - Warm, not Wacky: Friendly, but we don't use 10 emojis per sentence
///   - Active, not Passive: Guide the user forward
///     ✅ "Find your crowd" (active)
///     ❌ "Users can be found here" (passive)
///   - Concise: Mobile screens are small; we value the user's time
///
/// MESSAGING MAP (Onboarding Flow):
///
/// PHONE ENTRY:
///   ❌ "Enter your mobile number to continue." (system-speak)
///   ✅ "What's your number?"
///      <small>We'll send a quick code to get you in.</small>
///   Why: Feels like a natural start to a conversation.
///
/// OTP / VERIFY:
///   ❌ "Verification Code. Please enter the 6-digit code sent to your device." (clinical)
///   ✅ "Confirm it's you"
///      <small>Enter the code we just sent to +1...</small>
///   Why: "Verify" is a clinical/police word. "Confirm it's you" is personal.
///
/// USERNAME:
///   ❌ "Choose a unique username for your profile." (formal)
///   ✅ "How should we call you?"
///      <small>This is how friends will find you.</small>
///   Why: Emphasizes the social "hangout" aspect of the app.
///
/// PERMISSIONS:
///   ❌ "Allow Bleya to access your location." (technical)
///   ✅ "Where are we headed?"
///      <small>Share your location to see who's hanging out nearby.</small>
///   Why: Ties the technical request to a benefit (seeing friends).
///
/// ERROR & SUCCESS STATES:
///
/// Invalid OTP:
///   ❌ "Invalid Code" (accusatory)
///   ✅ "That code didn't quite match. Try one more time?" (encouraging, calm)
///
/// Success/Welcome:
///   ✅ "You're in. Let's find your first hangout."
///
/// THREE GOLDEN RULES OF BLEYA COPY:
///
/// 1. LOWER THE STAKES:
///    - Don't make things sound like a "Security Check"
///    - Make them sound like an "Introduction"
///    - Example: "Confirm it's you" not "Verify Identity"
///
/// 2. NO "COMPUTER WORDS":
///    ❌ Avoid: Submit, Processing, Input, Error, Execute
///    ✅ Use: Go, Hang out, Join, Oops, Done
///    - Keep it human and conversational
///
/// 3. TITLE CASE FOR HEADERS:
///    - Only the first letter is capitalized (Sentence case)
///    - Keeps it feeling casual and modern
///    ✅ "What's your number?"
///    ✅ "Confirm it's you"
///    ✅ "How should we call you?"
///    ❌ "What's Your Number?"
///    ❌ "CONFIRM IT'S YOU"
///
/// GENERAL PRINCIPLES:
///   - Move from utility to connection
///   - Sound like a knowledgeable, chill friend
///   - Be conversational, not robotic
///   - Use contractions naturally ("We'll", "You're", "It's")
///   - Active voice always
///   - Short sentences for clarity
///   - Even "bad" moments should feel calm and "Café Coast"
///
/// ========================================
/// 5. MOTION PRINCIPLES
/// ========================================
///
/// STAGGERED ENTRANCE:
///   - Content shouldn't just "appear"
///   - Headers slide up first, then inputs, then buttons
///   - 0.05s delay between each element
///   - Creates a sense of flow and intentionality
///
/// THE "SQUISH":
///   - Buttons should have a slight scale-down animation (scale: 0.95) when pressed
///   - Gives tactile feedback
///   - Makes interactions feel responsive and alive
///
/// WEIGHTLESS TRANSITIONS:
///   - When moving between screens, background orbs should stay persistent
///   - Text slides out while orbs remain
///   - Creates a "single-page" feel
///   - Maintains the weightless, continuous experience
///
/// ========================================
class BleyaTheme {
  // ========================================
  // CAFÉ COAST COLOR PALETTE
  // ========================================
  
  // BASE (Ice White - #F6F7FB)
  // Used for 90% of background. Slightly blue-tinted to feel "cooler" and premium.
  static const Color background = Color(0xFFF6F7FB);

  // TYPOGRAPHY (Deep Ocean Blue - #0B1220)
  // NEVER use pure black (#000000). This deep navy provides readability while staying "organic."
  static const Color foreground = Color(0xFF0B1220);
  static const Color mutedForeground = Color(0xFF556274); // Slate gray for secondary text

  // PRIMARY ACTION (Coat Blue - #1E6BFF)
  // Bright Mediterranean blue for main buttons and links. Use sparingly (20% rule).
  static const Color primary = Color(0xFF1E6BFF);

  // SECONDARY (Aqua Tint - #22D3EE)
  // Complementary to primary in gradients. Part of liquid background orbs.
  static const Color secondary = Color(0xFF22D3EE);

  // ACCENTS (Soft Sand - #FFB454 / Apricot)
  // Used for highlights, success states, or active orbs. Provides the "warmth."
  static const Color accent = Color(0xFFFFB454);
  static const Color success = Color(0xFF34D399); // Leaf
  static const Color error = Color(0xFFEF4444); // Error red (shade500 equivalent)
  static const Color errorBorder = Color(0xFFF87171); // Error border (shade400 equivalent)

  // Glass & Borders
  static const Color border = Color(0xFFE6EAF2); // Light border
  static const Color glassSurface = Color(0xFFFFFFFF); // White for glass effect

  // Glass opacity values
  // Glassmorphism: Semi-transparent white fill (bg-white/70) for frosted glass effect
  static const double glassOpacity = 0.82; // 70% opacity for glass surfaces
  static const double glassBorderOpacity = 0.1; // Subtle border for inner glow effect

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

  // Button text style (SF Pro - HIG compliant)
  static TextStyle get buttonText => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: '.SF Pro Text', // SF Pro on iOS
      );

  // ========================================
  // IMPLEMENTATION PATTERNS & GUIDELINES
  // ========================================
  //
  // When implementing new features or screens, follow these patterns.
  // Reference: "implement per design system" or "follow design system"
  //
  // ========================================
  // PAGE STRUCTURE
  // ========================================
  //
  // Every page should follow this structure:
  //
  // AnnotatedRegion<SystemUiOverlayStyle>(
  //   value: SystemUiOverlayStyle(
  //     statusBarColor: Colors.transparent,
  //     statusBarIconBrightness: Brightness.dark,
  //     statusBarBrightness: Brightness.light,
  //     systemNavigationBarColor: BleyaTheme.background,
  //     systemNavigationBarIconBrightness: Brightness.dark,
  //   ),
  //   child: Scaffold(
  //     backgroundColor: BleyaTheme.background,
  //     body: Stack(
  //       children: [
  //         // Liquid Glass Background (see Background Effects section)
  //         // Back button positioned at top (see Navigation section)
  //         // Main Content in SafeArea
  //         SafeArea(
  //           bottom: false,
  //           child: Column(
  //             children: [
  //               SizedBox(height: 16), // Header spacing
  //               Expanded(...), // Content
  //               // Footer with proper padding
  //               Padding(
  //                 padding: EdgeInsets.only(
  //                   left: BleyaTheme.footerPadding,
  //                   right: BleyaTheme.footerPadding,
  //                   top: BleyaTheme.footerPadding,
  //                   bottom: MediaQuery.of(context).padding.bottom +
  //                       BleyaTheme.footerBottomPadding,
  //                 ),
  //                 child: // Footer content
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   ),
  // )
  //
  // ========================================
  // STATUS BAR
  // ========================================
  //
  // Always use transparent status bar:
  // - statusBarColor: Colors.transparent
  // - statusBarIconBrightness: Brightness.dark
  // - statusBarBrightness: Brightness.light
  //
  // ========================================
  // NAVIGATION - BACK BUTTON
  // ========================================
  //
  // Back button should always be positioned at the very top:
  //
  // Positioned(
  //   top: MediaQuery.of(context).padding.top,
  //   left: 4,
  //   child: CupertinoButton(
  //     padding: EdgeInsets.zero,
  //     onPressed: () {
  //       if (Navigator.of(context).canPop()) {
  //         Navigator.of(context).pop();
  //       }
  //     },
  //     child: Icon(
  //       CupertinoIcons.chevron_left,
  //       color: BleyaTheme.mutedForeground,
  //       size: 28,
  //     ),
  //   ),
  // )
  //
  // ========================================
  // BACKGROUND EFFECTS - LIQUID GLASS
  // ========================================
  //
  // LIQUID BACKGROUNDS (Critical for "Café Coast" vibe):
  // Instead of static color, background has 2-3 large, blurry "orbs" that make the app feel "alive."
  // These orbs should slowly pulse or drift (consider adding animation).
  //
  // Top-right orb (Primary Blue):
  // Positioned(
  //   top: -80,
  //   right: -60,
  //   child: Container(
  //     width: 500,
  //     height: 500,
  //     decoration: BoxDecoration(
  //       shape: BoxShape.circle,
  //       color: BleyaTheme.primary.withValues(alpha: 0.06),
  //     ),
  //     child: BackdropFilter(
  //       filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
  //       child: Container(color: Colors.transparent),
  //     ),
  //   ),
  // ),
  //
  // Bottom-left orb (Apricot for warmth):
  // Positioned(
  //   bottom: -40,
  //   left: -60,
  //   child: Container(
  //     width: 400,
  //     height: 400,
  //     decoration: BoxDecoration(
  //       shape: BoxShape.circle,
  //       color: BleyaTheme.accent.withValues(alpha: 0.05), // Apricot provides the "warmth"
  //     ),
  //     child: BackdropFilter(
  //       filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
  //       child: Container(color: Colors.transparent),
  //     ),
  //   ),
  // ),
  //
  // GLASSMORPHISM CARDS:
  // - Use backdrop-blur (20px+)
  // - Semi-transparent white fill: BleyaTheme.glassSurface.withValues(alpha: BleyaTheme.glassOpacity)
  // - Inner glow: subtle 1px white border (top/left) to simulate light source
  // - Shadow: BleyaTheme.glassShadow
  //
  // ========================================
  // LAYOUT & SPACING
  // ========================================
  //
  // - Horizontal content padding: BleyaTheme.contentPadding (20px)
  // - Footer horizontal padding: BleyaTheme.footerPadding (20px)
  // - Footer bottom: MediaQuery.of(context).padding.bottom + BleyaTheme.footerBottomPadding
  // - Always use SafeArea(bottom: false, child: ...) for main content
  // - Header spacing after back button: SizedBox(height: 16)
  //
  // ========================================
  // INPUT FIELDS
  // ========================================
  //
  // - Container: Glass surface with backdrop filter
  // - Border radius: BleyaTheme.radiusLarge (20px) or BleyaTheme.radiusMedium (16px)
  // - Border: BleyaTheme.border (default), BleyaTheme.primary (focused), BleyaTheme.errorBorder (error)
  // - Padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18)
  // - Shadow: BleyaTheme.glassShadow
  // - Glass surface: BleyaTheme.glassSurface.withValues(alpha: BleyaTheme.glassOpacity)
  //
  // ========================================
  // ERROR HANDLING
  // ========================================
  //
  // VISUAL:
  // - Error text color: BleyaTheme.error or Colors.red.shade500
  // - Error border color: BleyaTheme.errorBorder
  // - Error text style: BleyaTheme.bodySmall with fontWeight: FontWeight.w500
  //
  // MESSAGING (Follow Bleya Voice Framework):
  // Even "bad" moments should feel calm and "Café Coast"
  //
  // Invalid OTP:
  //   ❌ "Invalid Code" (accusatory, system-speak)
  //   ✅ "That code didn't quite match. Try one more time?" (encouraging, calm)
  //
  // General Error Pattern:
  //   - Lower the stakes (not a security check, just a small hiccup)
  //   - No "computer words" (avoid "Error", use "Oops" or friendly phrasing)
  //   - Be encouraging, not accusatory
  //   - Example: "That doesn't look right. Try again?" not "Invalid input"
  //
  // ========================================
  // MOTION PRINCIPLES
  // ========================================
  //
  // STAGGERED ENTRANCE:
  //   - Content shouldn't just "appear"
  //   - Headers slide up first, then inputs, then buttons
  //   - 0.05s delay between each element
  //   - Creates a sense of flow and intentionality
  //   Example: Use AnimatedOpacity or SlideTransition with staggered delays
  //
  // THE "SQUISH":
  //   - Buttons should have a slight scale-down animation (scale: 0.95) when pressed
  //   - Gives tactile feedback
  //   - Makes interactions feel responsive and alive
  //   Example: Use GestureDetector with onTapDown/onTapUp and AnimatedScale
  //
  // WEIGHTLESS TRANSITIONS:
  //   - When moving between screens, background orbs should stay persistent
  //   - Text slides out while orbs remain
  //   - Creates a "single-page" feel
  //   - Maintains the weightless, continuous experience
  //   Example: Keep background orbs in a shared Stack, animate only content
  //
  // ========================================
  // REQUIRED IMPORTS
  // ========================================
  //
  // import 'dart:ui'; // For BackdropFilter and ImageFilter
  // import 'package:flutter/cupertino.dart';
  // import 'package:flutter/material.dart';
  // import 'package:flutter/services.dart'; // For SystemUiOverlayStyle
  // import '../constants/theme.dart';
  //
  // ========================================
}
