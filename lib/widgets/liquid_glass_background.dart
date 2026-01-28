import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Liquid Glass Background Component
///
/// A reusable background component with blurred orbs creating the "Liquid Glass" effect
/// following the Bleya Design System "Café Coast" visual language.
///
/// Features:
/// - Two large, blurry orbs positioned top-right and bottom-left
/// - Primary color orb (Coat Blue) - 500x500, alpha 0.06, blur 120px
/// - Secondary/Accent color orb (Soft Sand/Aqua) - 400x400, alpha 0.05, blur 100px
/// - Creates depth and warmth without heaviness
/// - Makes the app feel "alive" with subtle movement
class LiquidGlassBackground extends StatelessWidget {
  const LiquidGlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top-right orb (Primary - Coat Blue)
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BleyaTheme.primary.withValues(alpha: 0.06),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // Bottom-left orb (Secondary/Accent)
        Positioned(
          bottom: -40,
          left: -60,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BleyaTheme.secondary.withValues(alpha: 0.05),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }
}
