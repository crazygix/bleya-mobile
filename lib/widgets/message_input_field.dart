import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../utils/app_toast.dart';
import '../utils/utf16_length_limiting_text_input_formatter.dart';

/// Puts [unsent] back into [controller] after the server didn't store it.
/// Anything typed since stays, on the next line, so no text is lost.
void restoreUnsentDraft(TextEditingController controller, String unsent) {
  final current = controller.text;
  final restored = current.trim().isEmpty ? unsent : '$unsent\n$current';
  controller.value = TextEditingValue(
    text: restored,
    selection: TextSelection.collapsed(offset: restored.length),
  );
}

/// Message Input Field Component
///
/// A floating glassmorphic input bar for chat interfaces following
/// the ChatFlow_v2 design system.
///
/// Features:
/// - Floating bar with glass effect
/// - Camera and attachment buttons
/// - Text field that grows to [maxVisibleLines] lines, or a quarter of the
///   screen if that's less, then scrolls, so the send button stays in view
/// - Typing stops at the server's limit, [maxMessageLength]
/// - Send button
/// - Follows iOS design patterns
class MessageInputField extends StatefulWidget {
  /// The server's message limit, in UTF-16 code units (it counts like
  /// JavaScript's `String.length`). It cuts longer messages.
  static const int maxMessageLength = 2000;

  /// Shown instead of sending a message over [maxMessageLength]. Only a draft
  /// put back after a failed send can be that long.
  static const String tooLongMessage =
      'Messages can be up to 2,000 characters.';

  /// How many lines the field grows to before it scrolls.
  static const int maxVisibleLines = 6;

  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onSend;
  final VoidCallback? onCamera;
  final VoidCallback? onAttachment;
  final bool enabled;

  const MessageInputField({
    super.key,
    required this.controller,
    this.hintText = '',
    this.onSend,
    this.onCamera,
    this.onAttachment,
    this.enabled = true,
  });

  @override
  State<MessageInputField> createState() => _MessageInputFieldState();
}

class _MessageInputFieldState extends State<MessageInputField> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _send() {
    // The trimmed text is what gets sent.
    final length = widget.controller.text.trim().length;
    if (length > MessageInputField.maxMessageLength) {
      AppToast.showError(context, MessageInputField.tooLongMessage);
      return;
    }
    widget.onSend?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: BleyaTheme.footerPadding,
        right: BleyaTheme.footerPadding,
        top: BleyaTheme.spacingMD,
        bottom: MediaQuery.of(context).padding.bottom +
            BleyaTheme.footerBottomPadding,
      ),
      decoration: BoxDecoration(
        color: BleyaTheme.glassSurface.withValues(alpha: 0.0),
        border: Border(
          top: BorderSide(
            color: BleyaTheme.border.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BleyaTheme.spacingMD,
              vertical: BleyaTheme.spacingSM,
            ),
            decoration: BoxDecoration(
              color: BleyaTheme.glassSurface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: BleyaTheme.border.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.onCamera != null)
                  GestureDetector(
                    onTap: widget.enabled ? widget.onCamera : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: BleyaTheme.glassSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: BleyaTheme.border.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.camera,
                        size: 18,
                        color: BleyaTheme.primary,
                      ),
                    ),
                  ),
                if (widget.onCamera != null) const SizedBox(width: 8),
                if (widget.onAttachment != null)
                  GestureDetector(
                    onTap: widget.enabled ? widget.onAttachment : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: BleyaTheme.glassSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: BleyaTheme.border.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.plus,
                        size: 20,
                        color: BleyaTheme.primary,
                      ),
                    ),
                  ),
                if (widget.onAttachment != null) const SizedBox(width: 8),
                Expanded(
                  child: ConstrainedBox(
                    // A quarter of the screen caps the field at large text
                    // sizes, where six lines would be taller.
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height / 4,
                    ),
                    child: TextField(
                      controller: widget.controller,
                      enabled: widget.enabled,
                      minLines: 1,
                      maxLines: MessageInputField.maxVisibleLines,
                      inputFormatters: [
                        Utf16LengthLimitingTextInputFormatter(
                          MessageInputField.maxMessageLength,
                          maxLengthEnforcement: LengthLimitingTextInputFormatter
                              .getDefaultMaxLengthEnforcement(
                            Theme.of(context).platform,
                          ),
                        ),
                      ],
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(
                        fontSize: 16,
                        color: BleyaTheme.foreground,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          color: BleyaTheme.mutedForeground,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.enabled && _hasText && widget.onSend != null
                      ? _send
                      : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color:
                          _hasText ? BleyaTheme.primary : BleyaTheme.greyBorder,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.arrow_up,
                      size: 18,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
