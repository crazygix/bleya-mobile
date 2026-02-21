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
  final bool showSayHeyButton;
  final String? directRoomId;

  const UserDetailsPage({
    super.key,
    required this.userId,
    this.showSayHeyButton = true,
    this.directRoomId,
  });

  @override
  ConsumerState<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends ConsumerState<UserDetailsPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isCreatingChat = false;
  bool _isRunningDirectAction = false;
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

  Future<bool> _confirmDeleteChat() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete chat?'),
        content: const Text(
          "This only hides it from the list of chats. If you reopen the chat, it will be restored.",
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete chat'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<bool> _confirmUnblockUser() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Unblock user?'),
        content: const Text(
          'They will be able to message you again.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<bool> _confirmBlockUser() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Block user?'),
        content: const Text(
          'They will not be able to message you anymore.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  void _handleDirectActionResult(
    DirectChatActionResult result, {
    required bool shouldCloseCurrentChat,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(result.message)),
    );

    if (shouldCloseCurrentChat &&
        widget.directRoomId != null &&
        result.roomId != null &&
        result.roomId == widget.directRoomId) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        ModalRoute.withName('/'),
      );
      return;
    }
  }

  Future<void> _deleteDirectChat() async {
    setState(() => _isRunningDirectAction = true);
    try {
      final result = await deleteDirectChat(ref, widget.userId);
      if (!mounted) return;
      _handleDirectActionResult(result, shouldCloseCurrentChat: true);
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e is AppError
          ? e.getUserMessage()
          : "Couldn't delete this chat right now.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      if (mounted) {
        setState(() => _isRunningDirectAction = false);
      }
    }
  }

  Future<void> _unblockDirectChat() async {
    setState(() => _isRunningDirectAction = true);
    try {
      final result = await unblockDirectChat(ref, widget.userId);
      if (!mounted) return;
      _handleDirectActionResult(result, shouldCloseCurrentChat: false);
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e is AppError
          ? e.getUserMessage()
          : "Couldn't unblock this user right now.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      if (mounted) {
        setState(() => _isRunningDirectAction = false);
      }
    }
  }

  Future<void> _blockDirectChat() async {
    setState(() => _isRunningDirectAction = true);
    try {
      final result = await blockDirectChat(ref, widget.userId);
      if (!mounted) return;
      _handleDirectActionResult(result, shouldCloseCurrentChat: true);
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e is AppError
          ? e.getUserMessage()
          : "Couldn't block this user right now.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      if (mounted) {
        setState(() => _isRunningDirectAction = false);
      }
    }
  }

  Future<void> _showDirectChatActions(DirectChatStatus status) async {
    if (!status.hasChat || _isRunningDirectAction) {
      return;
    }

    if (status.isBlockedByMe) {
      await _showUnblockOnlyActions();
      return;
    }

    await _showBlockActions();
  }

  Future<void> _showBlockActions() async {
    final selectedAction = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('delete'),
            child: const Text('Delete chat'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('block'),
            child: const Text('Block user'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (!mounted || selectedAction == null) {
      return;
    }

    if (selectedAction == 'delete') {
      final confirmed = await _confirmDeleteChat();
      if (!mounted || !confirmed) return;
      await _deleteDirectChat();
      return;
    }

    if (selectedAction == 'block') {
      final confirmed = await _confirmBlockUser();
      if (!mounted || !confirmed) return;
      await _blockDirectChat();
    }
  }

  Future<void> _showUnblockOnlyActions() async {
    final selectedAction = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('unblock'),
            child: const Text('Unblock user'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (!mounted || selectedAction == null) {
      return;
    }

    if (selectedAction == 'unblock') {
      final confirmed = await _confirmUnblockUser();
      if (!mounted || !confirmed) return;
      await _unblockDirectChat();
      return;
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

  Widget? _buildHeaderAction({
    required bool isOwnProfile,
    required DirectChatStatus? directChatStatus,
    required bool isDirectStatusLoading,
  }) {
    if (isOwnProfile) {
      return null;
    }

    if (isDirectStatusLoading && !_isRunningDirectAction) {
      return const CupertinoActivityIndicator();
    }

    if (directChatStatus == null || !directChatStatus.hasChat) {
      return null;
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(
        BleyaTheme.iconContainerSize,
        BleyaTheme.iconContainerSize,
      ),
      onPressed: _isRunningDirectAction
          ? null
          : () => _showDirectChatActions(directChatStatus),
      child: _isRunningDirectAction
          ? const CupertinoActivityIndicator()
          : const Icon(
              CupertinoIcons.ellipsis_circle,
              size: 24,
              color: BleyaTheme.primary,
            ),
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
          child: Column(
            children: [
              const AppSkeleton.circle(size: 108),
              const SizedBox(height: BleyaTheme.spacingXL),
              const AppSkeleton(width: 180, height: 26),
              const SizedBox(height: BleyaTheme.spacingSM),
              const AppSkeleton(width: 220, height: 15),
              if (widget.showSayHeyButton) ...[
                const SizedBox(height: BleyaTheme.spacingXL),
                const AppSkeleton(
                  height: BleyaTheme.buttonHeight,
                  borderRadius: BorderRadius.all(
                    Radius.circular(BleyaTheme.radiusSmall),
                  ),
                ),
              ],
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

  Widget _buildHeroCard(
    UserProfile profile, {
    required bool isOwnProfile,
    required DirectChatStatus? directChatStatus,
  }) {
    final name = _displayName(profile);
    final isBlocked = directChatStatus?.isBlocked ?? false;
    final blockedByMe = directChatStatus?.isBlockedByMe ?? false;
    final blockedByOtherUser = directChatStatus?.isBlockedByOtherUser ?? false;
    final buttonText = _isCreatingChat
        ? 'Opening chat...'
        : blockedByMe
            ? 'Blocked'
            : blockedByOtherUser
                ? 'Unavailable'
                : 'Say hey';

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
          if (!isOwnProfile && widget.showSayHeyButton) ...[
            const SizedBox(height: BleyaTheme.spacingXL),
            PrimaryButton(
              text: buttonText,
              onPressed: isBlocked ? null : _startChat,
              isLoading: _isCreatingChat,
              isEnabled: !isBlocked,
              trailingIcon: isBlocked
                  ? null
                  : const Icon(
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
    required DirectChatStatus? directChatStatus,
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
          child: _buildHeroCard(
            profile,
            isOwnProfile: isOwnProfile,
            directChatStatus: directChatStatus,
          ),
        ),
        const SizedBox(height: BleyaTheme.spacingLG),
        _buildStaggered(
          order: 1,
          child: _buildBioCard(profile),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isOwnProfile,
    DirectChatStatus? directChatStatus,
  ) {
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
      directChatStatus: directChatStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;
    final isOwnProfile = currentUserId == widget.userId;
    final directStatusAsync = isOwnProfile
        ? null
        : ref.watch(directChatStatusProvider(widget.userId));
    final directChatStatus = directStatusAsync?.valueOrNull;
    final isDirectStatusLoading = directStatusAsync?.isLoading ?? false;

    return Scaffold(
      backgroundColor: BleyaTheme.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const LiquidGlassBackground(),
          Column(
            children: [
              GlassHeader(
                title: 'Profile',
                rightAction: _buildHeaderAction(
                  isOwnProfile: isOwnProfile,
                  directChatStatus: directChatStatus,
                  isDirectStatusLoading: isDirectStatusLoading,
                ),
              ),
              Expanded(
                child: _buildBody(
                  context,
                  isOwnProfile,
                  directChatStatus,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
