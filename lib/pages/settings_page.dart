import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/settings_menu_item.dart';
import '../providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../utils/app_errors.dart';
import '../utils/app_toast.dart';
import 'blocked_users_page.dart';
import 'edit_profile_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Future<void> _handleLogout() async {
    final shouldLogout = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      final logout = ref.read(logoutProvider);
      logout();
    }
  }

  Future<void> _navigateToEditProfile() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => EditProfilePage(),
      ),
    );
  }

  Future<void> _navigateToBlockedUsers() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const BlockedUsersPage(),
      ),
    );
  }

  void _showComingSoon(String feature) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(feature),
        content: const Text('Coming soon!'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildToastPreviewPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BleyaTheme.spacingLG),
      decoration: BoxDecoration(
        color:
            BleyaTheme.glassSurface.withValues(alpha: BleyaTheme.glassOpacity),
        borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
        border: Border.all(
          color: BleyaTheme.border,
          width: 1,
        ),
        boxShadow: BleyaTheme.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toast preview',
            style: BleyaTheme.bodyLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: BleyaTheme.spacingSM),
          Text(
            'Tap to test each variation.',
            style: BleyaTheme.bodySmall.copyWith(
              color: BleyaTheme.mutedForeground,
            ),
          ),
          const SizedBox(height: BleyaTheme.spacingMD),
          Wrap(
            spacing: BleyaTheme.spacingSM,
            runSpacing: BleyaTheme.spacingSM,
            children: [
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                color: BleyaTheme.primary,
                borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
                onPressed: () => AppToast.showInfo(
                  context,
                  'Info toast',
                ),
                child: const Text('Info'),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                color: BleyaTheme.success,
                borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
                onPressed: () => AppToast.showSuccess(
                  context,
                  'Success toast: Profile updated successfully.',
                ),
                child: const Text('Success'),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                color: BleyaTheme.error,
                borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
                onPressed: () => AppToast.showError(
                  context,
                  "Error toast: Couldn't save your changes. Try again?",
                ),
                child: const Text('Error'),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                color: BleyaTheme.mutedForeground,
                borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
                onPressed: () => AppToast.showInfo(
                  context,
                  'Long toast: This is a longer message to test wrapping and spacing in the iOS toast component.',
                ),
                child: const Text('Long'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;

    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    final isLoadingProfile = profile == null && profileAsync.isLoading;
    final username = profile?.username;
    final bio = profile?.bio;
    final profileImageUrl = profile?.profileImageUrl;
    final hasBio = bio != null && bio.trim().isNotEmpty;

    ref.listen(profileProvider, (previous, next) {
      final isNewError =
          next.hasError && (previous == null || !previous.hasError);
      if (!isNewError || !mounted) {
        return;
      }

      final error = next.error;
      final errorMessage = error is AppError
          ? error.getUserMessage()
          : "Couldn't load your profile. Try again?";

      AppToast.showError(context, errorMessage);
    });

    return Scaffold(
      backgroundColor: BleyaTheme.background,
      body: Stack(
        children: [
          const LiquidGlassBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.only(
                    left: BleyaTheme.contentPadding,
                    right: BleyaTheme.contentPadding,
                    top: BleyaTheme.spacingMD,
                    bottom: BleyaTheme.spacingLG,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Settings',
                        style: BleyaTheme.headingMedium.copyWith(fontSize: 34),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: BleyaTheme.contentPadding,
                    ),
                    child: Column(
                      children: [
                        // Profile Section
                        GestureDetector(
                          onTap: _navigateToEditProfile,
                          child: Container(
                            padding: const EdgeInsets.all(BleyaTheme.spacingLG),
                            decoration: BoxDecoration(
                              color: BleyaTheme.glassSurface
                                  .withValues(alpha: BleyaTheme.glassOpacity),
                              borderRadius: BorderRadius.circular(
                                  BleyaTheme.radiusMedium),
                              border: Border.all(
                                color: BleyaTheme.border,
                                width: 1,
                              ),
                              boxShadow: BleyaTheme.glassShadow,
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                isLoadingProfile
                                    ? const AppSkeleton.circle(size: 64)
                                    : ProfileAvatar(
                                        imageUrl: profileImageUrl,
                                        size: 64,
                                        backgroundColor:
                                            BleyaTheme.primaryLight,
                                        fallbackIcon: CupertinoIcons.person,
                                        fallbackIconColor:
                                            BleyaTheme.primaryDark,
                                      ),
                                const SizedBox(width: BleyaTheme.spacingLG),
                                // Username and bio
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: hasBio
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.center,
                                    children: [
                                      if (isLoadingProfile) ...[
                                        const AppSkeleton(
                                          width: 140,
                                          height: 20,
                                        ),
                                        const SizedBox(
                                          height: BleyaTheme.spacingXS,
                                        ),
                                        const AppSkeleton(
                                          width: 180,
                                          height: 14,
                                        ),
                                      ] else ...[
                                        Text(
                                          username ?? 'Username',
                                          style:
                                              BleyaTheme.headingMedium.copyWith(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (hasBio) ...[
                                          const SizedBox(
                                            height: BleyaTheme.spacingXS,
                                          ),
                                          Text(
                                            bio,
                                            style:
                                                BleyaTheme.bodyMedium.copyWith(
                                              fontSize: 14,
                                              color: BleyaTheme.mutedForeground,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: BleyaTheme.spacingSM),
                                // Chevron
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 20,
                                  color: BleyaTheme.mutedForeground,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: BleyaTheme.spacing3XL),
                        // Menu Items
                        SettingsMenuItem(
                          icon: CupertinoIcons.shield,
                          iconColor: Color(0xFF3B82F6), // Blue
                          label: 'Privacy',
                          onTap: () => _showComingSoon('Privacy'),
                        ),
                        const SizedBox(height: 4.0),
                        SettingsMenuItem(
                          icon: CupertinoIcons.person_crop_circle_badge_xmark,
                          iconColor: BleyaTheme.error,
                          label: 'Blocked users',
                          onTap: _navigateToBlockedUsers,
                        ),
                        const SizedBox(height: 4.0),
                        SettingsMenuItem(
                          icon: CupertinoIcons.bell,
                          iconColor: Color(0xFFEF4444), // Red
                          label: 'Notifications',
                          onTap: () => _showComingSoon('Notifications'),
                        ),
                        const SizedBox(height: 4.0),
                        SettingsMenuItem(
                          icon: CupertinoIcons.question_circle,
                          iconColor: BleyaTheme.primary,
                          label: 'Help',
                          onTap: () => _showComingSoon('Help'),
                        ),
                        const SizedBox(height: 4.0),
                        _buildToastPreviewPanel(),
                        const SizedBox(height: BleyaTheme.spacingSM),
                        SettingsMenuItem(
                          icon: CupertinoIcons.circle,
                          iconColor: Color(0xFFF97316), // Orange
                          label: 'Tell a Friend',
                          onTap: () => _showComingSoon('Tell a Friend'),
                        ),
                        const SizedBox(height: BleyaTheme.spacing3XL),
                        // Log Out
                        SettingsMenuItem(
                          icon: CupertinoIcons.arrow_right_square,
                          iconColor: BleyaTheme.error,
                          iconBackgroundColor:
                              BleyaTheme.error.withValues(alpha: 0.1),
                          label: 'Log Out',
                          labelColor: BleyaTheme.error,
                          onTap: _handleLogout,
                          showChevron: false,
                        ),
                        SizedBox(
                            height: padding.bottom + BleyaTheme.spacing2XL),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
