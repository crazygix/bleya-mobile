import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../domain/entities/room_member.dart';
import 'profile_avatar.dart';

class RoomHeroCard extends StatelessWidget {
  final String roomTitle;
  final String roomSubtitle;
  final String? imageUrl;

  const RoomHeroCard({
    super.key,
    required this.roomTitle,
    required this.roomSubtitle,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BleyaTheme.radiusLarge),
        border: Border.all(
          color: BleyaTheme.border.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          ...BleyaTheme.glassShadow,
          BoxShadow(
            color: BleyaTheme.primary.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BleyaTheme.radiusLarge),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _RoomCoverImage(imageUrl: imageUrl),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    BleyaTheme.foreground.withValues(alpha: 0.12),
                    BleyaTheme.foreground.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
            Positioned(
              left: BleyaTheme.spacingLG,
              right: BleyaTheme.spacingLG,
              bottom: BleyaTheme.spacingLG,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomTitle,
                    style: BleyaTheme.headingMedium.copyWith(
                      fontSize: 32,
                      color: Colors.white,
                      height: 1.0,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (roomSubtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: BleyaTheme.spacingXS),
                    Text(
                      roomSubtitle,
                      style: BleyaTheme.bodyLarge.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCoverImage extends StatelessWidget {
  final String? imageUrl;

  const _RoomCoverImage({required this.imageUrl});

  bool _isValidUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Widget _buildFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BleyaTheme.primary.withValues(alpha: 0.92),
            BleyaTheme.secondary.withValues(alpha: 0.75),
            BleyaTheme.accent.withValues(alpha: 0.7),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValidUrl(imageUrl)) {
      return _buildFallback();
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _buildFallback();
      },
      errorBuilder: (_, __, ___) => _buildFallback(),
    );
  }
}

class MembersSectionHeader extends StatelessWidget {
  final String memberCountLabel;

  const MembersSectionHeader({
    super.key,
    required this.memberCountLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Members',
          style: BleyaTheme.headingMedium.copyWith(
            fontSize: 30,
            height: 1.0,
          ),
        ),
        const SizedBox(width: BleyaTheme.spacingSM),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: BleyaTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            memberCountLabel,
            style: BleyaTheme.bodySmall.copyWith(
              color: BleyaTheme.primaryDark,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

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
    final displayName =
        member.username.isNotEmpty ? member.username : member.phoneNumber;
    final override = bioOverride?.trim() ?? '';
    final bioText = override.isNotEmpty ? override : member.bio.trim();
    final hasBio = bioText.isNotEmpty;

    return CupertinoButton(
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
              CupertinoIcons.chevron_right,
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

class EmptyMembersCard extends StatelessWidget {
  const EmptyMembersCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BleyaTheme.spacingXL),
      decoration: BoxDecoration(
        color: BleyaTheme.glassSurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
        border: Border.all(
          color: BleyaTheme.border.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: BleyaTheme.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.person_2,
            size: 24,
            color: BleyaTheme.primary,
          ),
          const SizedBox(height: BleyaTheme.spacingSM),
          Text(
            'No members yet',
            style: BleyaTheme.listTitle,
          ),
          const SizedBox(height: BleyaTheme.spacingXS),
          Text(
            'Invite friends to get this room going.',
            style: BleyaTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
