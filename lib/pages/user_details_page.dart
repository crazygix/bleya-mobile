import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../providers/chat_providers.dart';
import '../providers/use_case_providers.dart';
import '../utils/app_errors.dart';
import '../constants/theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/primary_button.dart';
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
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);
      final getUserByIdUseCase = ref.read(getUserByIdUseCaseProvider);
      final user = await getUserByIdUseCase(widget.userId);

      setState(() {
        _userData = user;
        _isLoading = false;
      });
    } catch (e) {
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
      setState(() => _isCreatingChat = true);

      // Create or get direct message room
      final room = await createDirectMessage(ref, widget.userId);

      if (mounted) {
        setState(() => _isCreatingChat = false);

        // Navigate to chat room
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChatRoomPage(room: room),
          ),
        );
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;
    final isOwnProfile = currentUserId == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('User not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Profile Image
                      ProfileAvatar(
                        imageUrl: _userData!['profileImageUrl']?.toString(),
                        size: 120,
                        backgroundColor: BleyaTheme.greyLight,
                        fallbackIcon: CupertinoIcons.person_fill,
                        fallbackIconColor: BleyaTheme.mutedForeground,
                      ),
                      const SizedBox(height: 24),
                      // Username
                      Text(
                        (_userData!['username']?.toString() ?? '').isNotEmpty
                            ? _userData!['username']
                            : 'No username',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 24),
                      // Chat Button (only show for other users)
                      if (!isOwnProfile)
                        PrimaryButton(
                          text: _isCreatingChat ? 'Opening chat...' : 'Chat',
                          onPressed: _startChat,
                          isLoading: _isCreatingChat,
                          trailingIcon: Icon(
                            CupertinoIcons.chat_bubble_fill,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      const SizedBox(height: 32),
                      // Bio Section
                      if (_userData!['bio'] != null &&
                          _userData!['bio'].toString().isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: BleyaTheme.greyLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'About',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _userData!['bio'],
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Additional Info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: BleyaTheme.greyLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Information',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            if (_userData!['createdAt'] != null)
                              _buildInfoRow(
                                context,
                                'Member since',
                                _formatDate(_userData!['createdAt']),
                              ),
                            if (_userData!['lastLogin'] != null) ...[
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                context,
                                'Last login',
                                _formatDate(_userData!['lastLogin']),
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

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = date is int
          ? DateTime.fromMillisecondsSinceEpoch(date)
          : (date is String
              ? DateTime.fromMillisecondsSinceEpoch(int.parse(date))
              : date as DateTime);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
