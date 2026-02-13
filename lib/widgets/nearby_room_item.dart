import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';
import '../domain/entities/room.dart';
import 'app_spinner.dart';
import 'profile_avatar.dart';

class NearbyRoomItem extends StatelessWidget {
  final Room room;
  final bool isJoining;
  final VoidCallback? onJoin;

  const NearbyRoomItem({
    super.key,
    required this.room,
    required this.isJoining,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final distanceLabel = room.distanceKm != null
        ? '${room.distanceKm!.toStringAsFixed(1)} km away'
        : 'Close by';

    return Padding(
      padding: EdgeInsets.only(bottom: BleyaTheme.spacingSM),
      child: GestureDetector(
        onTap: onJoin,
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
              ProfileAvatar(
                imageUrl: room.imageUrl,
                size: 48,
                backgroundColor: BleyaTheme.primaryLight,
                fallbackIcon: CupertinoIcons.building_2_fill,
                fallbackIconColor: BleyaTheme.primaryDark,
              ),
              SizedBox(width: BleyaTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: BleyaTheme.listTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: BleyaTheme.spacingXS),
                    Text(
                      distanceLabel,
                      style: BleyaTheme.bodySmall.copyWith(
                        fontSize: 12,
                        color: BleyaTheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: BleyaTheme.spacingSM),
              if (isJoining)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: AppSpinner(size: 22),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: BleyaTheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Join',
                    style: BleyaTheme.bodySmall.copyWith(
                      color: BleyaTheme.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
