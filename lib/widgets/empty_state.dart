import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';
import 'primary_button.dart';

/// Empty State Component
///
/// A reusable component for displaying empty states with icon, title, and description.
///
/// Features:
/// - Icon with customizable size and color
/// - Title and description text
/// - Optional action button
/// - Centered layout
/// - Uses design system typography and colors
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(BleyaTheme.spacing3XL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: BleyaTheme.mutedForeground.withValues(alpha: 0.5),
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
            if (actionText != null && onAction != null) ...[
              SizedBox(height: BleyaTheme.spacing2XL),
              PrimaryButton(
                text: actionText!,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
