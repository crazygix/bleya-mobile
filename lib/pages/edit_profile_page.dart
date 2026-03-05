import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/profile_providers.dart';
import '../providers/use_case_providers.dart';
import '../platform/app_text_field.dart';
import '../utils/app_errors.dart';
import '../utils/app_toast.dart';
import '../domain/entities/user_profile.dart';
import '../constants/theme.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/primary_button.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/app_navigation_bar.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isLoadingProfile = true;
  String? _profileImageUrl;
  File? _selectedImage;
  int _bioCharCount = 0;
  bool _bioFieldTouched = false;
  static const int _maxBioLength = 160;

  @override
  void initState() {
    super.initState();
    _bioController.addListener(_updateBioCharCount);
    _hydrateProfileFromCache();
    if (_isLoadingProfile) {
      _loadProfile();
    }
  }

  void _updateBioCharCount() {
    setState(() {
      _bioCharCount = _bioController.text.length;
    });
  }

  void _hydrateProfileFromCache() {
    final cachedProfile = ref.read(profileProvider).valueOrNull;
    if (cachedProfile == null) {
      return;
    }

    _usernameController.text = cachedProfile.username ?? '';
    _bioController.text = cachedProfile.bio ?? '';
    _bioCharCount = _bioController.text.length;
    _profileImageUrl = cachedProfile.profileImageUrl;
    _isLoadingProfile = false;
  }

  void _applyProfile(UserProfile profile, {bool clearSelectedImage = false}) {
    _usernameController.text = profile.username ?? '';
    _bioController.text = profile.bio ?? '';
    _bioCharCount = _bioController.text.length;

    setState(() {
      _profileImageUrl = profile.profileImageUrl;
      _isLoadingProfile = false;
      if (clearSelectedImage) {
        _selectedImage = null;
      }
    });
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    final cachedProfile = ref.read(profileProvider).valueOrNull;
    if (!forceRefresh && cachedProfile != null) {
      _applyProfile(cachedProfile);
      return;
    }

    setState(() => _isLoadingProfile = true);

    try {
      final profile = await ref
          .read(profileProvider.notifier)
          .fetchProfile(forceRefresh: forceRefresh);

      if (!mounted) return;
      _applyProfile(profile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
      String errorMessage;
      if (e is AppError) {
        errorMessage = e.getUserMessage();
      } else {
        errorMessage = "Couldn't load your profile. Try again?";
      }
      AppToast.showError(context, errorMessage);
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
            context, "Couldn't pick that image. Try another one?");
      }
    }
  }

  String? _getImageUrl() {
    if (_selectedImage != null) {
      return _selectedImage!.path;
    }
    if (_profileImageUrl != null &&
        _profileImageUrl!.isNotEmpty &&
        _profileImageUrl!.startsWith('https://')) {
      return _profileImageUrl;
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uploadImageUseCase = ref.read(uploadProfileImageUseCaseProvider);
      final updateProfileUseCase = ref.read(updateProfileUseCaseProvider);

      // Upload image first if selected
      if (_selectedImage != null) {
        await uploadImageUseCase(_selectedImage!);
      }

      // Update profile (username is read-only, only update bio)
      final updatedProfile = await updateProfileUseCase(
        bio: _bioController.text.trim(),
      );

      ref.read(profileProvider.notifier).setProfile(updatedProfile);

      if (mounted) {
        _applyProfile(updatedProfile, clearSelectedImage: true);
        AppToast.showSuccess(context, 'Profile updated successfully');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage;
        if (e is AppError) {
          errorMessage = e.getUserMessage();
        } else {
          errorMessage = "Couldn't update your profile. Try again?";
        }
        AppToast.showError(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _bioController.removeListener(_updateBioCharCount);
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Widget _buildProfileLoadingSkeleton() {
    return Expanded(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(BleyaTheme.contentPadding),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),
            Center(
              child: AppSkeleton.circle(size: 120),
            ),
            SizedBox(height: 24),
            AppSkeleton(
              width: 120,
              height: 14,
            ),
            SizedBox(height: 8),
            AppSkeleton(
              height: 56,
              borderRadius: BorderRadius.all(
                Radius.circular(BleyaTheme.radiusMedium),
              ),
            ),
            SizedBox(height: 24),
            AppSkeleton(
              width: 80,
              height: 14,
            ),
            SizedBox(height: 8),
            AppSkeleton(
              height: 120,
              borderRadius: BorderRadius.all(
                Radius.circular(BleyaTheme.radiusMedium),
              ),
            ),
            SizedBox(height: 28),
            AppSkeleton(
              height: BleyaTheme.buttonHeight,
              borderRadius: BorderRadius.all(
                Radius.circular(BleyaTheme.radiusSmall),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: BleyaTheme.background,
        body: Stack(
          children: [
            const LiquidGlassBackground(),
            SafeArea(
              child: Column(
                children: [
                  const AppNavigationBar(
                    title: 'Edit profile',
                  ),
                  _buildProfileLoadingSkeleton(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: BleyaTheme.background,
      body: Stack(
        children: [
          const LiquidGlassBackground(),
          SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header
                  const AppNavigationBar(
                    title: 'Edit profile',
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(BleyaTheme.contentPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          // Profile Image
                          Center(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final imageUrl = _getImageUrl();

                                      // Show selected file image
                                      if (_selectedImage != null) {
                                        return Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            image: DecorationImage(
                                              image: FileImage(_selectedImage!),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        );
                                      }

                                      // Show network image or fallback
                                      return ProfileAvatar(
                                        imageUrl: imageUrl,
                                        size: 120,
                                        backgroundColor:
                                            BleyaTheme.primaryLight,
                                        fallbackIcon: CupertinoIcons.person,
                                        fallbackIconColor:
                                            BleyaTheme.primaryDark,
                                      );
                                    },
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: BleyaTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.camera,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          // Username Field (Read-only)
                          AppTextField(
                            controller: _usernameController,
                            placeholder: 'Username',
                            contentPadding: const EdgeInsets.all(16),
                            enabled: false,
                            decoration: BoxDecoration(
                              color: BleyaTheme.glassSurface.withValues(
                                  alpha: BleyaTheme.glassOpacity * 0.5),
                              borderRadius: BorderRadius.circular(
                                  BleyaTheme.radiusMedium),
                              border: Border.all(
                                color: BleyaTheme.border.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            style: TextStyle(
                              color: BleyaTheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Bio Field
                          AppTextField(
                            controller: _bioController,
                            placeholder: 'A little about you',
                            contentPadding: const EdgeInsets.all(16),
                            maxLines: 4,
                            maxLength: _maxBioLength,
                            onChanged: (value) {
                              if (!_bioFieldTouched) {
                                setState(() => _bioFieldTouched = true);
                              }
                            },
                            decoration: BoxDecoration(
                              color: BleyaTheme.glassSurface
                                  .withValues(alpha: BleyaTheme.glassOpacity),
                              borderRadius: BorderRadius.circular(
                                  BleyaTheme.radiusMedium),
                              border: Border.all(
                                color: BleyaTheme.border,
                                width: 1,
                              ),
                            ),
                          ),
                          if (_bioFieldTouched) ...[
                            const SizedBox(height: 8),
                            // Character counter
                            Text(
                              '${_maxBioLength - _bioCharCount} left',
                              style: BleyaTheme.bodySmall.copyWith(
                                color: _bioCharCount > _maxBioLength
                                    ? BleyaTheme.error
                                    : BleyaTheme.mutedForeground,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Save Button (Pinned to bottom)
                  Padding(
                    padding: EdgeInsets.all(BleyaTheme.contentPadding),
                    child: PrimaryButton(
                      text: 'Save',
                      onPressed: _saveProfile,
                      isLoading: _isLoading,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
