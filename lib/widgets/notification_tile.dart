import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../domain/entities/notification.dart' as entity;
import '../../utils/time_formatter.dart';
import 'app_skeleton.dart';
import 'profile_avatar.dart';

class NotificationTile extends StatelessWidget {
  final entity.Notification notification;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BleyaTheme.contentPadding,
          vertical: BleyaTheme.spacingMD,
        ),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.transparent
              : BleyaTheme.primary.withValues(alpha: 0.05),
          border: Border(
            bottom: BorderSide(
              color: BleyaTheme.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(),
            const SizedBox(width: BleyaTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line 1: Room name + Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.roomName,
                          style: BleyaTheme.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: BleyaTheme.foreground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: BleyaTheme.spacingXS),
                      Text(
                        formatRelativeTime(notification.createdAt),
                        style: BleyaTheme.bodySmall.copyWith(
                          color: BleyaTheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Line 2: Action text
                  Text(
                    '${notification.senderName} replied to you',
                    style: BleyaTheme.bodySmall.copyWith(
                      color: BleyaTheme.foreground54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Line 3: Parent message context (if available)
                  if (notification.parentMessageText != null &&
                      notification.parentMessageText!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 4, bottom: 4),
                      padding: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: BleyaTheme.border,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        '"${notification.parentMessageText}"',
                        style: BleyaTheme.bodySmall.copyWith(
                          color: BleyaTheme.foreground54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Line 4: Reply content
                  Text(
                    notification.replyText ?? notification.previewText,
                    style: BleyaTheme.bodySmall.copyWith(
                      color: BleyaTheme.foreground87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                margin:
                    const EdgeInsets.only(left: BleyaTheme.spacingSM, top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: BleyaTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return _SenderAvatar(
      imageUrl: notification.senderAvatarUrl,
      senderName: notification.senderName,
    );
  }
}

/// The sender's photo, or their initial when there's no usable photo URL or
/// the image fails to load.
class _SenderAvatar extends StatefulWidget {
  final String? imageUrl;
  final String senderName;

  const _SenderAvatar({
    required this.imageUrl,
    required this.senderName,
  });

  @override
  State<_SenderAvatar> createState() => _SenderAvatarState();
}

class _SenderAvatarState extends State<_SenderAvatar> {
  static const double _size = 48;

  bool _imageLoadFailed = false;

  bool get _hasValidUrl {
    final uri = Uri.tryParse(widget.imageUrl ?? '');
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  void didUpdateWidget(_SenderAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageLoadFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showImage = _hasValidUrl && !_imageLoadFailed;

    return CircleAvatar(
      radius: _size / 2,
      backgroundColor: BleyaTheme.background,
      backgroundImage: showImage
          ? avatarImageProvider(
              widget.imageUrl!,
              size: _size,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            )
          : null,
      onBackgroundImageError: showImage
          ? (exception, stackTrace) {
              if (mounted) {
                setState(() => _imageLoadFailed = true);
              }
            }
          : null,
      child: showImage
          ? null
          : Text(
              widget.senderName.isNotEmpty
                  ? widget.senderName[0].toUpperCase()
                  : '?',
              style: BleyaTheme.headingMedium.copyWith(
                fontSize: 20,
                color: BleyaTheme.foreground,
              ),
            ),
    );
  }
}

class NotificationTileSkeleton extends StatelessWidget {
  const NotificationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BleyaTheme.contentPadding,
        vertical: BleyaTheme.spacingMD,
      ),
      child: Row(
        children: [
          const AppSkeleton.circle(size: 48),
          const SizedBox(width: BleyaTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                // Line 1: Room name
                AppSkeleton(width: 100, height: 14),
                SizedBox(height: BleyaTheme.spacingSM),
                // Line 2: Action text
                AppSkeleton(width: 180, height: 16),
                SizedBox(height: BleyaTheme.spacingSM),
                // Line 3: Parent quote
                AppSkeleton(width: double.infinity, height: 14),
                SizedBox(height: BleyaTheme.spacingXS),
                // Line 4: Reply preview
                AppSkeleton(width: 220, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
