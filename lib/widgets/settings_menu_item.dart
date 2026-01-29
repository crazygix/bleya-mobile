import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';

/// Settings Menu Item Component
///
/// A reusable menu item for settings screens with icon, label, and chevron.
///
/// Features:
/// - Colored icon with background
/// - Label text
/// - Right chevron indicator
/// - Optional custom text color (e.g., for destructive actions)
/// - Tap callback
/// - Glass card styling following design system
class SettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color? iconBackgroundColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;
  final bool showChevron;

  const SettingsMenuItem({
    super.key,
    required this.icon,
    required this.iconColor,
    this.iconBackgroundColor,
    required this.label,
    this.labelColor,
    required this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BleyaTheme.spacingLG,
          vertical: BleyaTheme.spacingLG,
        ),
        decoration: BoxDecoration(
          color: BleyaTheme.glassSurface
              .withValues(alpha: BleyaTheme.glassOpacity),
          borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
          border: Border.all(
            color: BleyaTheme.border,
            width: 1,
          ),
          boxShadow: BleyaTheme.glassShadow,
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackgroundColor ?? iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: BleyaTheme.spacingLG),
            // Label
            Expanded(
              child: Text(
                label,
                style: BleyaTheme.bodyLarge.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? BleyaTheme.foreground,
                ),
              ),
            ),
            // Chevron
            if (showChevron)
              Icon(
                CupertinoIcons.chevron_right,
                size: 20,
                color: BleyaTheme.mutedForeground,
              ),
          ],
        ),
      ),
    );
  }
}
