import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';

/// iOS-style Navigation Bar Component
///
/// A reusable navigation bar component following Apple's Human Interface Guidelines.
///
/// Features:
/// - 44pt height (HIG standard navigation bar height)
/// - Back button with proper 44x44pt touch target
/// - Optional title and trailing actions
/// - Uses design system colors and spacing
/// - Supports async callbacks for back button
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
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onBackPressed != null
                    ? () async => await onBackPressed!()
                    : () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    CupertinoIcons.chevron_left,
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
                style: BleyaTheme.headingMedium.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
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
