import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';
import '../domain/entities/room_member.dart';
import '../platform/app_button.dart';
import '../platform/app_icon.dart';
import 'profile_avatar.dart';

class RoomMemberTile extends StatelessWidget {
  final RoomMember member;
  final String? bioOverride;
  final bool isCurrentUser;
  final VoidCallback onTap;

  const RoomMemberTile({
    super.key,
    required this.member,
    this.bioOverride,
    required this.isCurrentUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = member.username.isNotEmpty ? member.username : 'Member';
    final override = bioOverride?.trim() ?? '';
    final bioText = override.isNotEmpty ? override : member.bio.trim();
    final hasBio = bioText.isNotEmpty;

    return AppButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.fromHeight(52),
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(BleyaTheme.radiusSmall),
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
              imageUrl: member.profileImageUrl,
              size: 48,
              backgroundColor: BleyaTheme.primaryLight,
              fallbackIcon: CupertinoIcons.person,
              fallbackIconColor: BleyaTheme.primaryDark,
            ),
            const SizedBox(width: BleyaTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:
                    hasBio ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          displayName,
                          style: BleyaTheme.listTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: BleyaTheme.spacingSM),
                        const _CurrentUserBadge(),
                      ],
                    ],
                  ),
                  if (hasBio) ...[
                    const SizedBox(height: BleyaTheme.spacingXS),
                    Text(
                      bioText,
                      style: BleyaTheme.bodySmall.copyWith(
                        color: BleyaTheme.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: BleyaTheme.spacingSM),
            Icon(
              AppIcon.chevronRight(context),
              size: 18,
              color: BleyaTheme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentUserBadge extends StatelessWidget {
  const _CurrentUserBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BleyaTheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: BleyaTheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        'you',
        style: BleyaTheme.bodySmall.copyWith(
          color: BleyaTheme.primaryDark,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}
