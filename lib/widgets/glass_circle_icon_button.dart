import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'pressable.dart';

/// Reusable circular glass icon button for compact actions.
///
/// Used for the dashboard add action and modal close action to keep a
/// consistent visual language across the app.
class GlassCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final Color? iconColor;
  final double size;
  final double iconSize;

  const GlassCircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.iconColor,
    this.size = 40,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Pressable(
        onTap: onPressed,
        // The brand's button squish.
        pressedScale: 0.95,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: BleyaTheme.glassSurface
                .withValues(alpha: BleyaTheme.glassOpacity),
            borderRadius: BorderRadius.circular(size / 2),
            border: Border.all(
              color: BleyaTheme.border,
              width: 1,
            ),
            boxShadow: BleyaTheme.glassShadow,
          ),
          child: Icon(
            icon,
            color: iconColor ?? BleyaTheme.primary,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
