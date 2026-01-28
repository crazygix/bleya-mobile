import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Secondary Button Component
///
/// A reusable secondary button component following Apple's Human Interface Guidelines
/// and the Bleya Design System.
///
/// Features:
/// - 56px height (HIG standard for primary buttons)
/// - 10px border radius (HIG standard for interactive elements)
/// - Border with no fill background
/// - Loading state with activity indicator
/// - Disabled state with muted appearance
/// - Uses design system typography and colors
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final Widget? trailingIcon;

  const SecondaryButton({
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
            color: Colors.transparent,
            border: Border.all(
              color: _isDisabled
                  ? BleyaTheme.mutedForeground.withValues(alpha: 0.3)
                  : BleyaTheme.primary,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CupertinoActivityIndicator(
                      color: BleyaTheme.primary,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        text,
                        style: BleyaTheme.buttonText.copyWith(
                          color: _isDisabled
                              ? BleyaTheme.mutedForeground
                                  .withValues(alpha: 0.5)
                              : BleyaTheme.primary,
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
