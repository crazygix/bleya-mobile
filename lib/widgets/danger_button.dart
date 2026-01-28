import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Danger Button Component
///
/// A reusable danger button component following Apple's Human Interface Guidelines
/// and the Bleya Design System.
///
/// Features:
/// - 56px height (HIG standard for primary buttons)
/// - 10px border radius (HIG standard for interactive elements)
/// - Red/error color for destructive actions
/// - Loading state with activity indicator
/// - Disabled state with muted appearance
/// - Uses design system typography and colors
class DangerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final Widget? trailingIcon;

  const DangerButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.trailingIcon,
  });

  bool get _isDisabled => !isEnabled || isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: BleyaTheme.buttonHeight,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        color: Colors.transparent,
        onPressed: _isDisabled ? null : onPressed,
        disabledColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: _isDisabled
                ? BleyaTheme.mutedForeground.withValues(alpha: 0.3)
                : BleyaTheme.error,
            borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
            boxShadow: _isDisabled
                ? null
                : [
                    BoxShadow(
                      color: BleyaTheme.error.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CupertinoActivityIndicator(
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        text,
                        style: BleyaTheme.buttonText.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      if (trailingIcon != null) ...[
                        SizedBox(width: BleyaTheme.spacingSM),
                        trailingIcon!,
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
