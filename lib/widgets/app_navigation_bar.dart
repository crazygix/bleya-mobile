import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';
import '../constants/ui_tokens.dart';
import '../platform/app_button.dart';
import '../platform/app_icon.dart';

/// iOS-style navigation bar component.
class AppNavigationBar extends StatelessWidget {
  final Future<void> Function()? onBackPressed;
  final String? title;
  final Widget? trailing;
  final bool showBackButton;

  const AppNavigationBar({
    super.key,
    this.onBackPressed,
    this.title,
    this.trailing,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Container(
      height: 44.0, // HIG standard navigation bar height
      padding: EdgeInsets.symmetric(
        horizontal: BleyaTheme.contentPadding,
      ),
      child: Row(
        children: [
          // Back button with proper touch target (44x44pt minimum)
          if (showBackButton)
            SizedBox(
              width: BleyaTheme.iconContainerSize, // 44pt minimum touch target
              height: BleyaTheme.iconContainerSize,
              child: AppButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: !canPop && onBackPressed == null
                    ? null
                    : onBackPressed != null
                        ? () async => await onBackPressed!()
                        : () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    AppIcon.back(context),
                    color: BleyaTheme.primary,
                    size: 28,
                  ),
                ),
              ),
            ),
          // Title (optional)
          if (title != null) ...[
            Expanded(
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: BleyaTheme.foreground,
                ).copyWith(fontFamily: UiTokens.systemFontFamily),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            Spacer(),
          // Trailing actions (optional)
          if (trailing != null)
            trailing!
          else if (showBackButton)
            SizedBox(width: BleyaTheme.iconContainerSize),
        ],
      ),
    );
  }
}
