import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../domain/entities/notification.dart' as entity;
import '../../utils/time_formatter.dart';
import 'app_skeleton.dart';

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.senderName,
                          style: BleyaTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
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
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'replied to your thread: ',
                          style: BleyaTheme.bodyMedium.copyWith(
                            color: BleyaTheme.mutedForeground,
                          ),
                        ),
                        TextSpan(
                          text: notification.previewText,
                          style: BleyaTheme.bodyMedium.copyWith(
                            color: BleyaTheme.foreground,
                          ),
                        ),
                      ],
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
    if (notification.senderAvatarUrl != null &&
        notification.senderAvatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(notification.senderAvatarUrl!),
        backgroundColor: BleyaTheme.background,
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: BleyaTheme.background,
      child: Text(
        notification.senderName.isNotEmpty
            ? notification.senderName[0].toUpperCase()
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
                AppSkeleton(width: 120, height: 16),
                SizedBox(height: BleyaTheme.spacingXS),
                AppSkeleton(width: double.infinity, height: 14),
                SizedBox(height: 4),
                AppSkeleton(width: 180, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
