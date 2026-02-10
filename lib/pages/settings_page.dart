import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/settings_menu_item.dart';
import '../providers/auth_providers.dart';
import '../providers/use_case_providers.dart';
import '../utils/app_errors.dart';
import 'edit_profile_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isLoadingProfile = true;
  String? _username;
  String? _bio;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      if (!mounted) return;
      setState(() => _isLoadingProfile = true);

      final getProfileUseCase = ref.read(getProfileUseCaseProvider);
      final profile = await getProfileUseCase();

      if (!mounted) return;
      setState(() {
        _username = profile.username;
        _bio = profile.bio;
        _profileImageUrl = profile.profileImageUrl;
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);

      if (mounted) {
        String errorMessage;
        if (e is AppError) {
          errorMessage = e.getUserMessage();
        } else {
          errorMessage = "Couldn't load your profile. Try again?";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

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
    // Reload profile when coming back
    _loadProfile();
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;
    final hasBio =
        !_isLoadingProfile && _bio != null && _bio!.trim().isNotEmpty;

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
                                _isLoadingProfile
                                    ? Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: BleyaTheme.greyLight,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: CupertinoActivityIndicator(),
                                        ),
                                      )
                                    : ProfileAvatar(
                                        imageUrl: _profileImageUrl,
                                        size: 64,
                                        backgroundColor: BleyaTheme.greyLight,
                                        fallbackIcon: CupertinoIcons.person,
                                        fallbackIconColor:
                                            BleyaTheme.mutedForeground,
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
                                      Text(
                                        _isLoadingProfile
                                            ? 'Loading...'
                                            : (_username ?? 'Username'),
                                        style:
                                            BleyaTheme.headingMedium.copyWith(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (hasBio) ...[
                                        const SizedBox(
                                            height: BleyaTheme.spacingXS),
                                        Text(
                                          _bio!,
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
                        const SizedBox(height: BleyaTheme.spacingSM),
                        SettingsMenuItem(
                          icon: CupertinoIcons.bell,
                          iconColor: Color(0xFFEF4444), // Red
                          label: 'Notifications',
                          onTap: () => _showComingSoon('Notifications'),
                        ),
                        const SizedBox(height: BleyaTheme.spacingSM),
                        SettingsMenuItem(
                          icon: CupertinoIcons.question_circle,
                          iconColor: BleyaTheme.primary,
                          label: 'Help',
                          onTap: () => _showComingSoon('Help'),
                        ),
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
