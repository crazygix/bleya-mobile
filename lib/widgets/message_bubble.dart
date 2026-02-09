import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';

/// Message Bubble Component
///
/// A refined message bubble component for chat interfaces following
/// the ChatFlow_v2 design system.
///
/// Features:
/// - Refined colors and styling for current user vs others
/// - Optional username display with tap action
/// - Optional reply count badge with icon
/// - Optional tap action for the whole bubble
/// - Max width of 75% of screen
/// - Improved visual hierarchy and spacing
class MessageBubble extends StatelessWidget {
  final String messageText;
  final bool isCurrentUser;
  final String? username;
  final int replyCount;
  final VoidCallback? onTap;
  final VoidCallback? onUsernameTap;
  final String? profileImageUrl;

  const MessageBubble({
    super.key,
    required this.messageText,
    required this.isCurrentUser,
    this.username,
    this.replyCount = 0,
    this.onTap,
    this.onUsernameTap,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BleyaTheme.greyLight,
              ),
              child: Icon(
                CupertinoIcons.person,
                size: 16,
                color: BleyaTheme.mutedForeground,
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: onTap,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isCurrentUser ? BleyaTheme.primary : BleyaTheme.greyLight,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(isCurrentUser ? 18 : 4),
                  bottomRight: Radius.circular(isCurrentUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser &&
                      username != null &&
                      username!.isNotEmpty)
                    GestureDetector(
                      onTap: onUsernameTap,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          username!,
                          style: TextStyle(
                            fontSize: 12,
                            color: BleyaTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Text(
                    messageText,
                    style: TextStyle(
                      fontSize: 16,
                      color: isCurrentUser
                          ? CupertinoColors.white
                          : BleyaTheme.foreground,
                      height: 1.4,
                    ),
                  ),
                  if (replyCount > 0) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? CupertinoColors.white.withValues(alpha: 0.2)
                              : BleyaTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.chat_bubble_text,
                              size: 12,
                              color: isCurrentUser
                                  ? CupertinoColors.white
                                  : BleyaTheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isCurrentUser
                                    ? CupertinoColors.white
                                    : BleyaTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
