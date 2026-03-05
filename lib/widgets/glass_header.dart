import 'dart:ui';
import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';
import '../constants/ui_tokens.dart';
import '../platform/app_button.dart';
import '../platform/app_icon.dart';

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
  final bool showBackButton;

  const GlassHeader({
    super.key,
    this.leftAction,
    this.title,
    this.subtitle,
    this.rightAction,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final canPop = Navigator.of(context).canPop();

    Widget? resolvedLeftAction = leftAction;
    if (resolvedLeftAction == null && showBackButton && canPop) {
      resolvedLeftAction = AppButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          BleyaTheme.iconContainerSize,
          BleyaTheme.iconContainerSize,
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: Icon(
          AppIcon.back(context),
          size: 28,
          color: BleyaTheme.primary,
        ),
      );
    }

    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: topPadding + 6,
            bottom: 6,
            left: BleyaTheme.contentPadding,
            right: BleyaTheme.contentPadding,
          ),
          decoration: BoxDecoration(
            color: BleyaTheme.glassSurface.withValues(alpha: 0.08),
            border: Border(
              bottom: BorderSide(
                color: BleyaTheme.border.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: BleyaTheme.iconContainerSize,
                height: BleyaTheme.iconContainerSize,
                child: resolvedLeftAction == null
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: resolvedLeftAction,
                      ),
              ),
              const SizedBox(width: BleyaTheme.spacingSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: BleyaTheme.foreground,
                        ).copyWith(fontFamily: UiTokens.systemFontFamily),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    if (hasSubtitle) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: BleyaTheme.mutedForeground,
                        ).copyWith(fontFamily: UiTokens.systemFontFamily),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: BleyaTheme.spacingSM),
              SizedBox(
                width: BleyaTheme.iconContainerSize,
                height: BleyaTheme.iconContainerSize,
                child: rightAction == null
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.centerRight,
                        child: rightAction,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
