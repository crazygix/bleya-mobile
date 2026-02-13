import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'primary_button.dart';

class CompactStateView extends StatelessWidget {
  final String title;
  final String description;
  final IconData? icon;
  final Widget? customIcon;
  final String? buttonText;
  final VoidCallback?
      onRetry; // Keep for backward compatibility or alias to onAction
  final VoidCallback? onAction;
  final Widget? trailingActionIcon;

  const CompactStateView({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.customIcon,
    this.buttonText,
    this.onRetry,
    this.onAction,
    this.trailingActionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnAction = onAction ?? onRetry;

    return Padding(
      padding: EdgeInsets.all(BleyaTheme.spacing3XL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: BleyaTheme.spacingXL),
          if (customIcon != null)
            customIcon!
          else
            Icon(
              icon ?? CupertinoIcons.exclamationmark_bubble,
              size: 64,
              color: icon == CupertinoIcons.map
                  ? BleyaTheme.primary
                  : BleyaTheme.mutedForeground,
            ),
          SizedBox(height: BleyaTheme.spacingXL),
          Text(
            title,
            style: BleyaTheme.headingMedium.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: BleyaTheme.spacingMD),
          Text(
            description,
            style: BleyaTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (effectiveOnAction != null) ...[
            SizedBox(height: BleyaTheme.spacing2XL),
            PrimaryButton(
              text: buttonText ?? 'Try again',
              onPressed: effectiveOnAction,
              trailingIcon: trailingActionIcon ??
                  Icon(
                    buttonText == 'Open Settings'
                        ? CupertinoIcons.settings
                        : CupertinoIcons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
            ),
            SizedBox(
              height:
                  MediaQuery.of(context).padding.bottom + BleyaTheme.spacingXS,
            ),
          ],
        ],
      ),
    );
  }
}
