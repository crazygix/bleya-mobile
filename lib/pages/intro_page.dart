import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/liquid_glass_background.dart';
import 'authorisation_page.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;

    return Scaffold(
      backgroundColor: BleyaTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Liquid Glass Background
          LiquidGlassBackground(),

          // Main Content - Scrollable
          SingleChildScrollView(
            padding: EdgeInsets.only(
              left: BleyaTheme.contentPadding,
              right: BleyaTheme.contentPadding,
              top: padding.top + BleyaTheme.spacing2XL,
              bottom: BleyaTheme.scrollBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand / Logo Area
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          BleyaTheme.foreground,
                          BleyaTheme.mutedForeground
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'Bleya',
                        style: BleyaTheme.headingLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: BleyaTheme.spacingSM),
                    Text(
                      'Built for solo travelers. Open to everyone.',
                      style: BleyaTheme.bodyLarge.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BleyaTheme.spacing2XL),

                // Hero tagline
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: BleyaTheme.foreground,
                    ),
                    children: [
                      TextSpan(text: 'Your next solo adventure starts with a '),
                      TextSpan(
                        text: 'conversation',
                        style: TextStyle(color: BleyaTheme.primary),
                      ),
                      TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: BleyaTheme.spacing3XL),

                // Features List - Glass cards
                Column(
                  children: [
                    _FeatureItem(
                      icon: CupertinoIcons.location,
                      iconColor: BleyaTheme.primary,
                      title: 'Discover people nearby',
                      description:
                          'Find people exploring the same city, even when you are on your own.',
                    ),
                    const SizedBox(height: BleyaTheme.spacingMD),
                    _FeatureItem(
                      icon: CupertinoIcons.person_2,
                      iconColor: BleyaTheme.secondary,
                      title: 'Connect Instantly',
                      description:
                          'Real-time chat that makes solo trips feel social.',
                    ),
                    const SizedBox(height: BleyaTheme.spacingMD),
                    _FeatureItem(
                      icon: CupertinoIcons.sparkles,
                      iconColor: BleyaTheme.accent,
                      title: 'No Hassle',
                      description:
                          'Sign up in 30 seconds. No passwords needed.',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer Action - Positioned at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(
                left: BleyaTheme.footerPadding,
                right: BleyaTheme.footerPadding,
                top: BleyaTheme.footerPadding,
                bottom: padding.bottom + BleyaTheme.footerBottomPadding,
              ),
              child: Column(
                children: [
                  PrimaryButton(
                    text: "Let's Go",
                    onPressed: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => AuthorisationPage(),
                        ),
                      );
                    },
                    trailingIcon: Icon(
                      CupertinoIcons.arrow_right,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: BleyaTheme.spacingLG),
                  Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    style: BleyaTheme.bodySmall.copyWith(
                      fontSize: 12,
                      color: BleyaTheme.mutedForeground.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BleyaTheme.cardPadding),
      decoration: BoxDecoration(
        color: BleyaTheme.glassSurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
        border: Border.all(
          color: BleyaTheme.border.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: BleyaTheme.glassShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: BleyaTheme.iconContainerSize,
            height: BleyaTheme.iconContainerSize,
            decoration: BoxDecoration(
              color: BleyaTheme.background,
              borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
              border: Border.all(
                color: BleyaTheme.border,
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
          const SizedBox(width: BleyaTheme.spacingLG),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: BleyaTheme.foreground,
                  ),
                ),
                const SizedBox(height: BleyaTheme.spacingXS),
                Text(
                  description,
                  style: BleyaTheme.bodySmall.copyWith(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
