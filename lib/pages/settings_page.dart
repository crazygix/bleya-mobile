import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/theme.dart';
import '../constants/urls.dart';
import '../providers/use_case_providers.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/settings_menu_item.dart';
import '../providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../platform/app_browser.dart';
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

  Future<void> _openUrl(String url) async {
    await AppBrowser.open(context, url);
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        left: BleyaTheme.spacingSM,
        bottom: BleyaTheme.spacingSM,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.toUpperCase(),
          style: BleyaTheme.bodySmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: BleyaTheme.mutedForeground,
          ),
        ),
      ),
    );
  }

  Future<void> _handleExportData() async {
    try {
      final data = await ref.read(exportDataUseCaseProvider)();
      final encoded = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bleya-data-export.json');
      await file.writeAsString(encoded);
      if (!mounted) return;
      // On iPad the share sheet is a popover that must be anchored to a source
      // rect — omitting sharePositionOrigin makes shareXFiles throw there.
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'My Bleya data',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Export data failed: $e');
        debugPrint('$stackTrace');
      }
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
                        _sectionLabel('Privacy & safety'),
                        SettingsMenuItem(
                          icon: CupertinoIcons.person_crop_circle_badge_xmark,
                          iconColor: BleyaTheme.error,
                          label: 'Blocked users',
                          onTap: _navigateToBlockedUsers,
                        ),
                        const SizedBox(height: BleyaTheme.spacing2XL),
                        _sectionLabel('About'),
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
                        const SizedBox(height: BleyaTheme.spacing2XL),
                        _sectionLabel('Account'),
                        SettingsMenuItem(
                          icon: CupertinoIcons.arrow_down_doc,
                          iconColor: BleyaTheme.primary,
                          label: 'Export my data',
                          onTap: _handleExportData,
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
                        // Log Out — kept apart as the very last row.
                        const SizedBox(height: BleyaTheme.spacing3XL),
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
