import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../platform/app_button.dart';
import 'app_spinner.dart';

/// Primary button component.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final Widget? trailingIcon;

  const PrimaryButton({
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
      child: AppButton(
        padding: EdgeInsets.zero,
        onPressed: _isDisabled ? null : onPressed,
        variant: AppButtonVariant.plain,
        color: Colors.transparent,
        disabledColor: Colors.transparent,
        borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
        child: Container(
          decoration: BoxDecoration(
            gradient: _isDisabled ? null : BleyaTheme.skywashGradient,
            color: _isDisabled
                ? BleyaTheme.mutedForeground.withValues(alpha: 0.3)
                : null,
            borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
            boxShadow: _isDisabled ? null : BleyaTheme.primaryShadow,
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: AppSpinner(
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
