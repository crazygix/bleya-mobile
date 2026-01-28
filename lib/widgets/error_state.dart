import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';

/// Error State Component
///
/// A reusable component for displaying error states with icon, title, description, and retry action.
///
/// Features:
/// - Error icon with red color
/// - Title and description text
/// - Optional retry button
/// - Centered layout
/// - Uses design system typography and colors
/// - Follows Bleya Voice Framework (encouraging, not accusatory)
class ErrorState extends StatelessWidget {
  final String title;
  final String description;
  final String? retryText;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorState({
    super.key,
    this.title = 'Oops, something went wrong',
    required this.description,
    this.retryText = 'Try again',
    this.onRetry,
    this.icon = CupertinoIcons.exclamationmark_triangle,
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
              color: BleyaTheme.error,
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
            if (retryText != null && onRetry != null) ...[
              SizedBox(height: BleyaTheme.spacing2XL),
              CupertinoButton(
                onPressed: onRetry,
                child: Text(
                  retryText!,
                  style: BleyaTheme.buttonText.copyWith(
                    color: BleyaTheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
