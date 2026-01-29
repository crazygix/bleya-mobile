import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';
import '../domain/entities/room.dart';
import 'profile_avatar.dart';

/// Room Card Component
///
/// A reusable card component for displaying room information in a list.
///
/// Features:
/// - Glass morphism effect following Bleya Design System
/// - Avatar with fallback for room type
/// - Room name and subtitle (last message or location detail)
/// - Time and unread badge
/// - Chevron icon
/// - Tap action
class RoomCard extends StatelessWidget {
  final Room room;
  final String subtitle;
  final String time;
  final int unreadCount;
  final VoidCallback onTap;

  const RoomCard({
    super.key,
    required this.room,
    required this.subtitle,
    required this.time,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: BleyaTheme.spacingMD),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(BleyaTheme.spacingLG),
          decoration: BoxDecoration(
            color: BleyaTheme.glassSurface
                .withValues(alpha: BleyaTheme.glassOpacity),
            borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
            border: Border.all(
              color: BleyaTheme.border,
              width: 1,
            ),
            boxShadow: BleyaTheme.glassShadow,
          ),
          child: Row(
            children: [
              // Avatar
              ProfileAvatar(
                imageUrl: null,
                size: 56,
                backgroundColor: room.isPrivate
                    ? BleyaTheme.privateRoomLight
                    : BleyaTheme.primaryLight,
                fallbackIcon: room.isPrivate
                    ? CupertinoIcons.person_fill
                    : CupertinoIcons.person_2_fill,
                fallbackIconColor: room.isPrivate
                    ? BleyaTheme.privateRoomDark
                    : BleyaTheme.primaryDark,
              ),
              SizedBox(width: BleyaTheme.spacingLG),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: BleyaTheme.headingMedium.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: BleyaTheme.spacingXS),
                    Text(
                      subtitle,
                      style: BleyaTheme.bodyMedium.copyWith(
                        fontSize: 14,
                        color: BleyaTheme.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: BleyaTheme.spacingSM),
              // Right info (time + unread badge)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: BleyaTheme.bodySmall.copyWith(
                      color: unreadCount > 0
                          ? BleyaTheme.primary
                          : BleyaTheme.mutedForeground.withValues(alpha: 0.4),
                    ),
                  ),
                  SizedBox(height: BleyaTheme.spacingXS),
                  if (unreadCount > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: BleyaTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: BleyaTheme.bodySmall.copyWith(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: BleyaTheme.mutedForeground.withValues(alpha: 0.3),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
