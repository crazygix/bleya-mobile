import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../domain/entities/blocked_user.dart';
import '../platform/app_route.dart';
import '../providers/profile_providers.dart';
import '../utils/app_errors.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/glass_header.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/profile_avatar.dart';
import 'user_details_page.dart';

class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  Widget _buildOpticallyCenteredState(Widget child) {
    return Transform.translate(
      offset: const Offset(0, -24),
      child: child,
    );
  }

  Future<void> _openUserDetails(
      BuildContext context, WidgetRef ref, String userId) async {
    await Navigator.of(context).push(
      AppRoute.build(
        builder: (context) => UserDetailsPage(
          userId: userId,
        ),
      ),
    );

    ref.invalidate(blockedUsersProvider);
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        BleyaTheme.contentPadding,
        BleyaTheme.spacingLG,
        BleyaTheme.contentPadding,
        BleyaTheme.spacing2XL,
      ),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: BleyaTheme.spacingSM),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(BleyaTheme.spacingMD),
        decoration: BoxDecoration(
          color: BleyaTheme.glassSurface
              .withValues(alpha: BleyaTheme.glassOpacity),
          borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
          border: Border.all(
            color: BleyaTheme.border.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: BleyaTheme.glassShadow,
        ),
        child: const Row(
          children: [
            AppSkeleton.circle(size: 48),
            SizedBox(width: BleyaTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(width: 120, height: 16),
                  SizedBox(height: BleyaTheme.spacingXS),
                  AppSkeleton(width: 180, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<BlockedUser> users) {
    if (users.isEmpty) {
      return _buildOpticallyCenteredState(
        const EmptyState(
          icon: CupertinoIcons.shield,
          title: 'No blocked users',
          description: 'People you block will appear here.',
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        BleyaTheme.contentPadding,
        BleyaTheme.spacingLG,
        BleyaTheme.contentPadding,
        MediaQuery.of(context).padding.bottom + BleyaTheme.spacing2XL,
      ),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: BleyaTheme.spacingSM),
      itemBuilder: (context, index) {
        final user = users[index];
        final displayName =
            user.username.trim().isNotEmpty ? user.username : 'Guest';

        return GestureDetector(
          onTap: () => _openUserDetails(context, ref, user.id),
          child: Container(
            padding: const EdgeInsets.all(BleyaTheme.spacingMD),
            decoration: BoxDecoration(
              color: BleyaTheme.glassSurface
                  .withValues(alpha: BleyaTheme.glassOpacity),
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
                  imageUrl: user.profileImageUrl,
                  size: 48,
                  backgroundColor: BleyaTheme.primaryLight,
                  fallbackIcon: CupertinoIcons.person,
                  fallbackIconColor: BleyaTheme.primaryDark,
                ),
                const SizedBox(width: BleyaTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: BleyaTheme.listTitle.copyWith(
                          color: BleyaTheme.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user.bio.trim().isNotEmpty) ...[
                        const SizedBox(height: BleyaTheme.spacingXS),
                        Text(
                          user.bio,
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
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsersAsync = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: BleyaTheme.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const LiquidGlassBackground(),
          Column(
            children: [
              const GlassHeader(
                title: 'Blocked users',
              ),
              Expanded(
                child: blockedUsersAsync.when(
                  loading: _buildLoadingState,
                  error: (error, _) => _buildOpticallyCenteredState(
                    ErrorState(
                      title: "Couldn't load blocked users",
                      description: error is AppError
                          ? error.getUserMessage()
                          : "Something went wrong. Try again?",
                      onRetry: () => ref.invalidate(blockedUsersProvider),
                    ),
                  ),
                  data: (users) => _buildList(context, ref, users),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
