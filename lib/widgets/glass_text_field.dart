import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../platform/app_text_field.dart';

/// Glass Text Field Component
///
/// A reusable text field with glassmorphism design following the Bleya Design System.
///
/// Features:
/// - Glass surface with backdrop blur effect
/// - Border with focus states (primary when focused, error when error state)
/// - Optional leading icon
/// - Optional error message display
/// - Customizable placeholder and keyboard type
/// - Uses design system colors and spacing
class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final Color? trailingIconColor;
  final String? errorMessage;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final Widget? prefix;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final int maxLines;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    this.leadingIcon,
    this.trailingIcon,
    this.trailingIconColor,
    this.errorMessage,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.textInputAction,
    this.autofillHints,
    this.prefix,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BleyaTheme.glassSurface,
        borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
        border: Border.all(
          color: errorMessage != null
              ? BleyaTheme.errorBorder
              : (focusNode.hasFocus ? BleyaTheme.primary : BleyaTheme.border),
          width: 1,
        ),
        boxShadow: BleyaTheme.glassShadow,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: BleyaTheme.spacingLG,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                color: BleyaTheme.mutedForeground,
                size: 20,
              ),
              SizedBox(width: BleyaTheme.spacingMD),
            ],
            if (prefix != null) ...[
              prefix!,
              SizedBox(width: 4),
            ],
            Expanded(
              child: AppTextField(
                controller: controller,
                focusNode: focusNode,
                placeholder: placeholder,
                autofillHints: autofillHints,
                textInputAction: textInputAction,
                keyboardType: keyboardType,
                textCapitalization: textCapitalization,
                inputFormatters: inputFormatters,
                obscureText: obscureText,
                autocorrect: autocorrect,
                enableSuggestions: enableSuggestions,
                maxLines: maxLines,
                style: BleyaTheme.bodyLarge.copyWith(
                  color: BleyaTheme.foreground,
                  fontWeight: FontWeight.w600,
                ),
                placeholderStyle: BleyaTheme.bodyLarge.copyWith(
                  color: BleyaTheme.mutedForeground.withValues(alpha: 0.6),
                ),
                decoration: const BoxDecoration(color: Colors.transparent),
                contentPadding: EdgeInsets.symmetric(
                  vertical: BleyaTheme.spacingLG + 2,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              SizedBox(width: BleyaTheme.spacingMD),
              Icon(
                trailingIcon,
                color: trailingIconColor ?? BleyaTheme.mutedForeground,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
