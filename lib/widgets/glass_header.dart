import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Glass Header Component
///
/// iOS-style glassmorphic header with blur effect.
///
/// Features:
/// - Backdrop blur for glassmorphism effect
/// - Optional left action (back button, etc.)
/// - Title and subtitle support
/// - Optional right action (info button, etc.)
/// - Semi-transparent background
/// - Follows Bleya "Café Coast" design system
class GlassHeader extends StatelessWidget {
  final Widget? leftAction;
  final String? title;
  final String? subtitle;
  final Widget? rightAction;

  const GlassHeader({
    super.key,
    this.leftAction,
    this.title,
    this.subtitle,
    this.rightAction,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: topPadding + 8,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: BleyaTheme.glassSurface.withValues(alpha: 0.0),
            border: Border(
              bottom: BorderSide(
                color: BleyaTheme.border.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              if (leftAction != null) ...[
                leftAction!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: BleyaTheme.foreground,
                        ),
                      ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: BleyaTheme.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (rightAction != null) ...[
                const SizedBox(width: 12),
                rightAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
