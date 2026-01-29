import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';

/// Message Bubble Component
///
/// A reusable message bubble component for chat interfaces.
///
/// Features:
/// - Different colors for current user vs others
/// - Optional username display with tap action
/// - Optional reply count badge
/// - Optional tap action for the whole bubble
/// - Max width of 75% of screen
/// - Uses design system colors and typography
class MessageBubble extends StatelessWidget {
  final String messageText;
  final bool isCurrentUser;
  final String? username;
  final int replyCount;
  final VoidCallback? onTap;
  final VoidCallback? onUsernameTap;

  const MessageBubble({
    super.key,
    required this.messageText,
    required this.isCurrentUser,
    this.username,
    this.replyCount = 0,
    this.onTap,
    this.onUsernameTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? BleyaTheme.primaryDark
                  : BleyaTheme.greyMedium,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username (for other users only)
                if (!isCurrentUser && username != null && username!.isNotEmpty)
                  GestureDetector(
                    onTap: onUsernameTap,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      username!,
                      style: TextStyle(
                        fontSize: 12,
                        color: BleyaTheme.primaryDark,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                if (!isCurrentUser && username != null && username!.isNotEmpty)
                  const SizedBox(height: 4),
                // Message text
                Text(
                  messageText,
                  style: TextStyle(
                    color: isCurrentUser
                        ? CupertinoColors.white
                        : BleyaTheme.foreground87,
                  ),
                ),
                // Reply count badge
                if (replyCount > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? BleyaTheme.primaryDark
                          : BleyaTheme.greyBorder,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.chat_bubble_text,
                          size: 14,
                          color: isCurrentUser
                              ? CupertinoColors.white
                              : BleyaTheme.foreground54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCurrentUser
                                ? CupertinoColors.white
                                : BleyaTheme.foreground54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
