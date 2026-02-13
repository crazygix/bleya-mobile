## Bleya Mobile - Theme, Brand, and Design System Rules

The original Bleya design system and brand guidance live at the top of `lib/constants/theme.dart`.
Their content is preserved below as code for reference.

```dart
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
///   - Active, not Passive: Guide the user forward (use active voice)
///   - Concise: Mobile screens are small; we value the user's time
///
/// THREE GOLDEN RULES OF BLEYA COPY:
///
/// 1. LOWER THE STAKES:
///    - Don't make things sound like a "Security Check"
///    - Make them sound like an "Introduction"
///
/// 2. NO "COMPUTER WORDS":
///    ❌ Avoid: Submit, Processing, Input, Error, Execute, Verify, Submit
///    ✅ Use: Go, Get code, Hang out, Join, Oops, Done, Confirm
///    - Keep it human and conversational
///
/// 3. SENTENCE CASE FOR HEADERS:
///    - Only the first letter is capitalized (Sentence case)
///    - Keeps it feeling casual and modern
///
/// GENERAL PRINCIPLES:
///   - Move from utility to connection
///   - Sound like a knowledgeable, chill friend
///   - Be conversational, not robotic
///   - Use contractions naturally
///   - Active voice always
///   - Short sentences for clarity
///   - Even "bad" moments should feel calm and "Café Coast"
///   - Error messages: Encouraging, not accusatory
///   - Success messages: Welcoming and forward-looking
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
/// ICONOGRAPHY - Hybrid Icon Strategy
/// ========================================
///
/// This design system uses a hybrid approach balancing HIG compliance with brand needs:
///
/// SYSTEM ACTIONS (CupertinoIcons - SF Symbols - HIG Compliant):
///   - Navigation icons: chevron_left, chevron_right, xmark, etc.
///   - Common actions: settings, share, search, heart, bookmark, etc.
///   - System buttons and controls
///   - Standard UI elements
///   Usage: CupertinoIcons.icon_name
///   Size: 20-28px depending on context
///   Color: BleyaTheme.mutedForeground (default), BleyaTheme.primary (active)
///
/// BRAND-SPECIFIC FEATURES (Custom Icons - When Needed):
///   - Unique brand features that don't have SF Symbol equivalents
///   - Highly distinctive brand elements
///   - Should still follow HIG principles (simple, clear, consistent)
///
/// Apple HIG Icon Principles:
///   1. Use SF Symbols (CupertinoIcons) for system actions
///   2. Keep icons simple, clear, and recognizable at small sizes
///   3. Maintain consistent size, stroke weight, and perspective
///   4. Avoid text within icons
///   5. Ensure icons are legible and accessible
///
/// COMMON ICONS:
///   - Back: CupertinoIcons.chevron_left (size: 28)
///   - Close: CupertinoIcons.xmark
///   - Settings: CupertinoIcons.settings
///   - Share: CupertinoIcons.share
///   - Search: CupertinoIcons.search
///   - Heart: CupertinoIcons.heart / heart_fill
///   - Camera: CupertinoIcons.camera / camera_fill
///   - Phone: CupertinoIcons.phone
///   - Shield: CupertinoIcons.shield (for privacy/security)
///
/// This approach ensures:
///   1. HIG compliance for native iOS feel (SF Symbols for system actions)
///   2. Brand flexibility when needed (custom icons for unique features)
///   3. Consistency across all screens
///
/// ========================================
/// TYPOGRAPHY - Hybrid Font Strategy
/// ========================================
///
/// This design system uses a hybrid approach balancing HIG compliance with brand identity:
///
/// BRAND MOMENTS (Outfit - Custom Font via Google Fonts):
///   - Main brand name/logo text
///   - Hero headlines and taglines
///   - Feature titles and prominent headings (page titles)
///   - Marketing/promotional text
///   Usage: GoogleFonts.outfit() or BleyaTheme.headingLarge/headingMedium
///   Weight: FontWeight.w800 (extra bold)
///   Examples: "What's your number?", "Confirm it's you", "How should we call you?"
///   Note: Follow sentence case (only first letter capitalized) per Bleya Voice Framework
///
/// UI ELEMENTS (SF Pro - HIG Compliant):
///   - Body text and descriptions
///   - Button labels
///   - Navigation text
///   - Legal/disclaimer text
///   - Form labels and input text
///   - General UI copy
///   Usage: BleyaTheme.bodyLarge/bodyMedium/bodySmall/buttonText
///   Weight: FontWeight.normal (body), FontWeight.bold (buttons)
///   Examples: "We'll send you a code. Quick and secure.", "This is how friends will find you."
///
/// FONT SIZES:
///   - headingLarge: 44px (hero moments)
///   - headingMedium: 34px (page titles)
///   - bodyLarge: 17px (descriptions, main body)
///   - bodyMedium: 16px (secondary text)
///   - bodySmall: 13px (captions, hints)
///   - buttonText: 18px (button labels)
///
/// This approach ensures:
///   1. HIG compliance for native iOS feel (SF Pro for UI)
///   2. Brand differentiation (Outfit for brand moments)
///   3. Consistency across all screens
///
/// ========================================
/// IMPLEMENTATION GUIDELINES
/// ========================================
///
/// When implementing new features or screens, follow these guidelines.
/// Reference: "implement per design system" or "follow design system"
///
/// PAGE STRUCTURE:
///   - Transparent status bar (see existing pages)
///   - Back button positioned at top using MediaQuery.padding.top
///   - Liquid glass background with 2-3 blurry orbs (primary + accent colors)
///   - SafeArea(bottom: false) for main content
///   - Use BleyaTheme constants for spacing, padding, colors
///
/// GLASSMORPHISM:
///   - Backdrop blur: 20px+
///   - Semi-transparent white: glassSurface.withValues(alpha: glassOpacity)
///   - Inner glow: 1px white border (top/left)
///   - Shadow: glassShadow
///
/// MOTION:
///   - Staggered entrance: 0.05s delay between elements
///   - Button "squish": scale 0.95 on press
///   - Weightless transitions: orbs persist, content animates
```

## 6. UI COMPONENT STANDARDS

We maintain strict standards for common UI patterns to ensure consistency.

### STANDARD LIST CELL (e.g., RoomCard, NearbyResult)

Used for any list item representing a person, room, or entity.

- **Background**: `glassSurface.withValues(alpha: 0.5)`
- **Border**: `border.withValues(alpha: 0.3)` width 1px
- **Corner Radius**: `radiusSmall` (10.0px) -- **NOT** radiusMedium
- **Padding**: `radiusSmall` (10.0px) internal padding
- **Avatar Size**: 48.0px
- **Spacing**: `spacingMD` (12.0px) between avatar and content
- **Typography**:
    - Title: `listTitle` (16px, w700)
    - Subtitle: `bodySmall` (differs by context, typically muted)


