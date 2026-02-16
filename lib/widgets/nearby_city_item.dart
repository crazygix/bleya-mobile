import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';
import '../domain/entities/city.dart';
import 'app_spinner.dart';
import 'profile_avatar.dart';

class NearbyCityItem extends StatelessWidget {
  final City city;
  final bool isJoining;
  final VoidCallback? onJoin;

  const NearbyCityItem({
    super.key,
    required this.city,
    required this.isJoining,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
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
                imageUrl: city.imageUrl,
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
                      city.name,
                      style: BleyaTheme.listTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: BleyaTheme.spacingXS),
                    Text(
                      city.countryName,
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
