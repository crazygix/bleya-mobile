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
      padding: EdgeInsets.only(bottom: BleyaTheme.spacingSM),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(BleyaTheme.radiusSmall),
          decoration: BoxDecoration(
            color: BleyaTheme.glassSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
            border: Border.all(
              color: BleyaTheme.border.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: BleyaTheme.glassShadow,
          ),
          child: Row(
            children: [
              // Avatar
              ProfileAvatar(
                imageUrl: null,
                size: 48,
                backgroundColor: room.isPrivate
                    ? BleyaTheme.privateRoomLight
                    : BleyaTheme.primaryLight,
                fallbackIcon: room.isPrivate
                    ? CupertinoIcons.person
                    : CupertinoIcons.person_2,
                fallbackIconColor: room.isPrivate
                    ? BleyaTheme.privateRoomDark
                    : BleyaTheme.primaryDark,
              ),
              SizedBox(width: BleyaTheme.spacingMD),
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
                      fontSize: 12,
                      color: BleyaTheme.mutedForeground,
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    SizedBox(height: BleyaTheme.spacingXS),
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
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
