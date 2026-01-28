import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import 'glass_text_field.dart';

/// Form Field Component
///
/// A complete form field component with label, input, and feedback states.
/// Combines GlassTextField with optional label and state-based feedback text.
///
/// Features:
/// - Optional label above the field
/// - Glass-style text input
/// - Three feedback states (priority order):
///   1. Error (red, highest priority)
///   2. Success (green, medium priority)
///   3. Helper (grey, lowest priority - informational)
/// - Icons for each feedback state
/// - Consistent spacing and styling
/// - Uses design system colors and typography
///
/// State Priority:
/// - If errorMessage is provided, show error (red)
/// - Else if showSuccess is true and successMessage provided, show success (green)
/// - Else if helperText is provided, show helper (grey)
/// - Otherwise show nothing below the field
class FormField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;

  // Label
  final String? label;

  // Input customization
  final IconData? leadingIcon;
  final Widget? prefix;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final bool obscureText;
  final int maxLines;

  // Feedback states (priority: error > success > helper)
  final String? errorMessage;
  final bool showSuccess;
  final String? successMessage;
  final String? helperText;

  const FormField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    this.label,
    this.leadingIcon,
    this.prefix,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.maxLines = 1,
    this.errorMessage,
    this.showSuccess = false,
    this.successMessage,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Optional label above field
        if (label != null) ...[
          Text(
            label!,
            style: BleyaTheme.bodyMedium.copyWith(
              color: BleyaTheme.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: BleyaTheme.spacingSM),
        ],

        // Glass text field
        GlassTextField(
          controller: controller,
          focusNode: focusNode,
          placeholder: placeholder,
          leadingIcon: leadingIcon,
          prefix: prefix,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          obscureText: obscureText,
          maxLines: maxLines,
          errorMessage: errorMessage, // Used for border color
        ),

        // Feedback text below field (priority: error > success > helper)
        if (_shouldShowFeedback) ...[
          SizedBox(height: BleyaTheme.spacingSM),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _feedbackIcon,
                size: 14,
                color: _feedbackColor,
              ),
              SizedBox(width: BleyaTheme.spacingXS + 2),
              Expanded(
                child: Text(
                  _feedbackText!,
                  style: BleyaTheme.bodySmall.copyWith(
                    color: _feedbackColor,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Check if any feedback should be shown
  bool get _shouldShowFeedback {
    return errorMessage != null ||
        (showSuccess && successMessage != null) ||
        helperText != null;
  }

  // Get feedback text based on priority
  String? get _feedbackText {
    if (errorMessage != null) return errorMessage;
    if (showSuccess && successMessage != null) return successMessage;
    if (helperText != null) return helperText;
    return null;
  }

  // Get feedback color based on state
  Color get _feedbackColor {
    if (errorMessage != null) return BleyaTheme.error;
    if (showSuccess && successMessage != null) return BleyaTheme.success;
    return BleyaTheme.mutedForeground;
  }

  // Get feedback icon based on state
  IconData get _feedbackIcon {
    if (errorMessage != null) return CupertinoIcons.exclamationmark_circle_fill;
    if (showSuccess && successMessage != null) {
      return CupertinoIcons.checkmark_circle_fill;
    }
    return CupertinoIcons.info_circle;
  }
}
