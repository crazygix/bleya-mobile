import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../constants/urls.dart';
import '../platform/app_browser.dart';
import '../platform/app_dialog.dart';
import '../platform/app_route.dart';
import '../providers/auth_providers.dart';
import '../widgets/primary_button.dart';
import '../widgets/liquid_glass_background.dart';
import 'authorisation_page.dart';

class IntroPage extends ConsumerStatefulWidget {
  const IntroPage({super.key});

  @override
  ConsumerState<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends ConsumerState<IntroPage> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl(LegalUrls.terms);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl(LegalUrls.privacy);

    // If we landed here after a forced logout (ban/suspend), show the reason once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final message = ref.read(fatalAuthMessageProvider);
      if (message != null && message.isNotEmpty && mounted) {
        ref.read(fatalAuthMessageProvider.notifier).state = null;
        AppDialog.alert(
          context,
          title: 'Account access',
          message: message,
          buttonText: 'OK',
        );
      }
    });
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    await AppBrowser.open(context, url);
  }

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
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Bleya',
                            style: BleyaTheme.headingLarge,
                          ),
                          TextSpan(
                            text: '.',
                            style: BleyaTheme.headingLarge.copyWith(
                              color: BleyaTheme.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: BleyaTheme.spacingSM),
                    Text(
                      'Built for solo travelers.\nOpen to everyone.',
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
                    style: BleyaTheme.heroTagline,
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
                        AppRoute.build(
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
                  Text.rich(
                    TextSpan(
                      style: BleyaTheme.bodySmall.copyWith(
                        fontSize: 12,
                        color:
                            BleyaTheme.mutedForeground.withValues(alpha: 0.7),
                      ),
                      children: [
                        const TextSpan(
                            text: 'By continuing, you agree to our '),
                        TextSpan(
                          text: 'Terms',
                          style: TextStyle(
                            color: BleyaTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: _termsRecognizer,
                        ),
                        const TextSpan(text: ' & '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: BleyaTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: _privacyRecognizer,
                        ),
                      ],
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
                  style: BleyaTheme.featureTitle,
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
