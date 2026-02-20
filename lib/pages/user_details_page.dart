import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../providers/chat_providers.dart';
import '../providers/use_case_providers.dart';
import '../utils/app_errors.dart';
import '../constants/theme.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/primary_button.dart';
import '../widgets/glass_header.dart';
import '../widgets/liquid_glass_background.dart';
import '../domain/entities/user_profile.dart';
import 'chat_room_page.dart';

class UserDetailsPage extends ConsumerStatefulWidget {
  final String userId;

  const UserDetailsPage({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends ConsumerState<UserDetailsPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isCreatingChat = false;
  UserProfile? _userData;
  String? _loadErrorMessage;
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _loadErrorMessage = null;
      });

      final getUserByIdUseCase = ref.read(getUserByIdUseCaseProvider);
      final user = await getUserByIdUseCase(widget.userId);

      if (!mounted) return;
      setState(() {
        _userData = user;
        _isLoading = false;
        _loadErrorMessage = null;
      });
      _entranceController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      final errorMessage =
          e is AppError ? e.getUserMessage() : "Couldn't load this profile.";
      setState(() {
        _isLoading = false;
        _loadErrorMessage = errorMessage;
      });
    }
  }

  Future<void> _startChat() async {
    try {
      if (!mounted) return;
      setState(() => _isCreatingChat = true);

      // Create or get direct message room
      final room = await createDirectMessage(ref, widget.userId);

      if (!mounted) return;
      setState(() => _isCreatingChat = false);

      // Navigate to chat room
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (context) => ChatRoomPage(room: room),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingChat = false);

      if (mounted) {
        String errorMessage;
        if (e is AppError) {
          errorMessage = e.getUserMessage();
        } else {
          errorMessage = "Couldn't start the chat. Try again?";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  Widget _buildStaggered({
    required int order,
    required Widget child,
  }) {
    final start = (order * 0.06).clamp(0.0, 0.75).toDouble();
    final end = (start + 0.25).clamp(0.25, 1.0).toDouble();

    final animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
    );
  }

  BoxDecoration _glassCardDecoration({double alpha = 0.58}) {
    return BoxDecoration(
      color: BleyaTheme.glassSurface.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(BleyaTheme.radiusLarge),
      border: Border.all(
        color: BleyaTheme.border.withValues(alpha: 0.3),
        width: 1,
      ),
      boxShadow: BleyaTheme.glassShadow,
    );
  }

  String _displayName(UserProfile profile) {
    final username = profile.username?.trim() ?? '';
    if (username.isNotEmpty) return username;
    return 'Guest';
  }

  Widget _buildUserDetailsSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BleyaTheme.contentPadding,
        BleyaTheme.spacingLG,
        BleyaTheme.contentPadding,
        BleyaTheme.spacing3XL,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(BleyaTheme.spacing2XL),
          decoration: _glassCardDecoration(alpha: 0.62),
          child: const Column(
            children: [
              AppSkeleton.circle(size: 108),
              SizedBox(height: BleyaTheme.spacingXL),
              AppSkeleton(width: 180, height: 26),
              SizedBox(height: BleyaTheme.spacingSM),
              AppSkeleton(width: 220, height: 15),
              SizedBox(height: BleyaTheme.spacingXL),
              AppSkeleton(
                height: BleyaTheme.buttonHeight,
                borderRadius: BorderRadius.all(
                  Radius.circular(BleyaTheme.radiusSmall),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BleyaTheme.spacingLG),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(BleyaTheme.spacingXL),
          decoration: _glassCardDecoration(alpha: 0.6),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: 90, height: 18),
              SizedBox(height: BleyaTheme.spacingMD),
              AppSkeleton(height: 14),
              SizedBox(height: BleyaTheme.spacingSM),
              AppSkeleton(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(UserProfile profile, {required bool isOwnProfile}) {
    final name = _displayName(profile);

    return Container(
      padding: const EdgeInsets.all(BleyaTheme.spacing2XL),
      decoration: _glassCardDecoration(alpha: 0.62),
      child: Column(
        children: [
          ProfileAvatar(
            imageUrl: profile.profileImageUrl,
            size: 108,
            borderColor: Colors.white.withValues(alpha: 0.7),
            borderWidth: 2,
            backgroundColor: BleyaTheme.primaryLight,
            fallbackIcon: CupertinoIcons.person,
            fallbackIconColor: BleyaTheme.primaryDark,
          ),
          const SizedBox(height: BleyaTheme.spacingXL),
          Text(
            name,
            style: BleyaTheme.headingMedium.copyWith(
              fontSize: 32,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          if (!isOwnProfile) ...[
            const SizedBox(height: BleyaTheme.spacingXL),
            PrimaryButton(
              text: _isCreatingChat ? 'Opening chat...' : 'Say hey',
              onPressed: _startChat,
              isLoading: _isCreatingChat,
              trailingIcon: const Icon(
                CupertinoIcons.chat_bubble,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBioCard(UserProfile profile) {
    final bio = profile.bio?.trim() ?? '';
    final hasBio = bio.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BleyaTheme.spacingXL),
      decoration: _glassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.quote_bubble,
                size: 20,
                color: BleyaTheme.primary,
              ),
              const SizedBox(width: BleyaTheme.spacingSM),
              Text(
                'About',
                style: BleyaTheme.listTitle.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: BleyaTheme.spacingMD),
          Text(
            hasBio ? bio : 'No bio yet.',
            style: BleyaTheme.bodyLarge.copyWith(
              color:
                  hasBio ? BleyaTheme.foreground87 : BleyaTheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedContent({
    required UserProfile profile,
    required bool isOwnProfile,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BleyaTheme.contentPadding,
        BleyaTheme.spacingLG,
        BleyaTheme.contentPadding,
        BleyaTheme.spacing3XL,
      ),
      children: [
        _buildStaggered(
          order: 0,
          child: _buildHeroCard(profile, isOwnProfile: isOwnProfile),
        ),
        const SizedBox(height: BleyaTheme.spacingLG),
        _buildStaggered(
          order: 1,
          child: _buildBioCard(profile),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, bool isOwnProfile) {
    if (_isLoading) {
      return _buildUserDetailsSkeleton();
    }

    if (_loadErrorMessage != null) {
      return ErrorState(
        title: "Couldn't open profile",
        description: _loadErrorMessage!,
        onRetry: _loadUserData,
      );
    }

    final userData = _userData;
    if (userData == null) {
      return const EmptyState(
        icon: CupertinoIcons.person,
        title: 'No profile yet',
        description: "Looks like this profile isn't available right now.",
      );
    }

    return _buildLoadedContent(
      profile: userData,
      isOwnProfile: isOwnProfile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;
    final isOwnProfile = currentUserId == widget.userId;

    return Scaffold(
      backgroundColor: BleyaTheme.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const LiquidGlassBackground(),
          Column(
            children: [
              const GlassHeader(
                title: 'Profile',
              ),
              Expanded(
                child: _buildBody(context, isOwnProfile),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
