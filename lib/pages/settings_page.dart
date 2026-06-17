import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/theme.dart';
import '../constants/urls.dart';
import '../providers/use_case_providers.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/settings_menu_item.dart';
import '../providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../platform/app_dialog.dart';
import '../platform/app_route.dart';
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
    final shouldLogout = await AppDialog.confirm(
      context,
      title: 'Log out',
      message: 'Are you sure you want to log out?',
      confirmText: 'Log out',
      destructive: true,
    );

    if (shouldLogout) {
      final logout = ref.read(logoutProvider);
      await logout();
    }
  }

  Future<void> _navigateToEditProfile() async {
    await Navigator.of(context).push(
      AppRoute.build(
        builder: (context) => EditProfilePage(),
      ),
    );
  }

  Future<void> _navigateToBlockedUsers() async {
    await Navigator.of(context).push(
      AppRoute.build(
        builder: (context) => const BlockedUsersPage(),
      ),
    );
  }

  void _showComingSoon(String feature) {
    AppDialog.alert(
      context,
      title: feature,
      message: 'Coming soon!',
      buttonText: 'OK',
    );
  }

  Future<void> _openUrl(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      AppToast.showError(context, "Couldn't open the link.");
    }
  }

  Future<void> _handleExportData() async {
    try {
      final data = await ref.read(exportDataUseCaseProvider)();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bleya-data-export.json');
      await file.writeAsString(json);
      await Share.shareXFiles([XFile(file.path)], subject: 'My Bleya data');
    } catch (e) {
      if (!mounted) return;
      final message = e is AppError
          ? e.getUserMessage()
          : "Couldn't export your data. Try again?";
      AppToast.showError(context, message);
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete account',
      message:
          'This permanently deletes your account, profile, and messages. This cannot be undone.',
      confirmText: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(deleteAccountUseCaseProvider)();
      final logout = ref.read(logoutProvider);
      await logout();
    } catch (e) {
      if (!mounted) return;
      final message = e is AppError
          ? e.getUserMessage()
          : "Couldn't delete your account. Try again?";
      AppToast.showError(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;

    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    final isLoadingProfile = profile == null;
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
                        SettingsMenuItem(
                          icon: CupertinoIcons.shield,
                          iconColor: Color(0xFF3B82F6), // Blue
                          label: 'Privacy Policy',
                          onTap: () => _openUrl(LegalUrls.privacy),
                        ),
                        const SizedBox(height: 4.0),
                        SettingsMenuItem(
                          icon: CupertinoIcons.doc_text,
                          iconColor: Color(0xFF6366F1), // Indigo
                          label: 'Terms of Service',
                          onTap: () => _openUrl(LegalUrls.terms),
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
                        SettingsMenuItem(
                          icon: CupertinoIcons.circle,
                          iconColor: Color(0xFFF97316), // Orange
                          label: 'Tell a Friend',
                          onTap: () => _showComingSoon('Tell a Friend'),
                        ),
                        const SizedBox(height: BleyaTheme.spacing3XL),
                        SettingsMenuItem(
                          icon: CupertinoIcons.arrow_down_doc,
                          iconColor: BleyaTheme.primary,
                          label: 'Export my data',
                          onTap: _handleExportData,
                        ),
                        const SizedBox(height: 4.0),
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
                        const SizedBox(height: 4.0),
                        SettingsMenuItem(
                          icon: CupertinoIcons.trash,
                          iconColor: BleyaTheme.error,
                          iconBackgroundColor:
                              BleyaTheme.error.withValues(alpha: 0.1),
                          label: 'Delete account',
                          labelColor: BleyaTheme.error,
                          onTap: _handleDeleteAccount,
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
