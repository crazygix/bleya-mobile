import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../providers/chat_providers.dart';
import '../providers/use_case_providers.dart';
import '../utils/app_errors.dart';
import '../constants/theme.dart';
import '../widgets/app_skeleton.dart';
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

class _UserDetailsPageState extends ConsumerState<UserDetailsPage> {
  bool _isLoading = true;
  bool _isCreatingChat = false;
  UserProfile? _userData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final getUserByIdUseCase = ref.read(getUserByIdUseCaseProvider);
      final user = await getUserByIdUseCase(widget.userId);

      if (!mounted) return;
      setState(() {
        _userData = user;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (mounted) {
        String errorMessage;
        if (e is AppError) {
          errorMessage = e.getUserMessage();
        } else {
          errorMessage = "Couldn't load that user. Try again?";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
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
        MaterialPageRoute(
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

  Widget _buildUserDetailsSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: BleyaTheme.glassSurface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: BleyaTheme.border.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: BleyaTheme.glassShadow,
            ),
            child: const Column(
              children: [
                AppSkeleton.circle(size: 100),
                SizedBox(height: 20),
                AppSkeleton(width: 170, height: 24),
                SizedBox(height: 20),
                AppSkeleton(
                  height: BleyaTheme.buttonHeight,
                  borderRadius: BorderRadius.all(
                    Radius.circular(BleyaTheme.radiusSmall),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BleyaTheme.glassSurface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: BleyaTheme.border.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 80, height: 16),
                SizedBox(height: 12),
                AppSkeleton(height: 14),
                SizedBox(height: 8),
                AppSkeleton(height: 14),
                SizedBox(height: 8),
                AppSkeleton(width: 120, height: 14),
              ],
            ),
          ),
        ],
      ),
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
              GlassHeader(
                title: 'User Details',
              ),
              Expanded(
                child: _isLoading
                    ? _buildUserDetailsSkeleton()
                    : _userData == null
                        ? Center(
                            child: Text(
                              'User not found',
                              style: TextStyle(
                                fontSize: 16,
                                color: BleyaTheme.mutedForeground,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: BleyaTheme.glassSurface
                                        .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: BleyaTheme.border
                                          .withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                    boxShadow: BleyaTheme.glassShadow,
                                  ),
                                  child: Column(
                                    children: [
                                      ProfileAvatar(
                                        imageUrl: _userData!.profileImageUrl,
                                        size: 100,
                                        backgroundColor:
                                            BleyaTheme.primaryLight,
                                        fallbackIcon: CupertinoIcons.person,
                                        fallbackIconColor:
                                            BleyaTheme.primaryDark,
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        _userData!.username?.isNotEmpty == true
                                            ? _userData!.username!
                                            : 'No username',
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: BleyaTheme.foreground,
                                        ),
                                      ),
                                      if (!isOwnProfile) ...[
                                        const SizedBox(height: 20),
                                        PrimaryButton(
                                          text: _isCreatingChat
                                              ? 'Opening chat...'
                                              : 'Chat',
                                          onPressed: _startChat,
                                          isLoading: _isCreatingChat,
                                          trailingIcon: Icon(
                                            CupertinoIcons.chat_bubble,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (_userData!.bio?.isNotEmpty == true)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: BleyaTheme.glassSurface
                                          .withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: BleyaTheme.border
                                            .withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'About',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: BleyaTheme.foreground,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _userData!.bio!,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: BleyaTheme.foreground,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_userData!.bio?.isNotEmpty == true)
                                  const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: BleyaTheme.glassSurface
                                        .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: BleyaTheme.border
                                          .withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Information',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: BleyaTheme.foreground,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      if (_userData!.createdAt != null)
                                        _buildInfoRow(
                                          context,
                                          'Member since',
                                          _formatDate(_userData!.createdAt),
                                        ),
                                      if (_userData!.lastLogin != null) ...[
                                        const SizedBox(height: 12),
                                        _buildInfoRow(
                                          context,
                                          'Last login',
                                          _formatDate(_userData!.lastLogin),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: BleyaTheme.greyText,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}
