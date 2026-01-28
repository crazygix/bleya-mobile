import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Message Input Field Component
///
/// A reusable message input component for chat interfaces.
///
/// Features:
/// - Text field with rounded borders
/// - Send button with icon
/// - Shadow effect for elevation
/// - Optional placeholder text
/// - Optional send callback
/// - Uses design system colors and styling
class MessageInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onSend;
  final bool enabled;

  const MessageInputField({
    super.key,
    required this.controller,
    this.hintText = 'Type a message...',
    this.onSend,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: BleyaTheme.greyText.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: hintText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              CupertinoIcons.arrow_up_circle_fill,
              color: BleyaTheme.primary,
              size: 36,
            ),
            onPressed: enabled ? onSend : null,
          ),
        ],
      ),
    );
  }
}
