import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/use_case_providers.dart';
import '../utils/app_errors.dart';
import '../constants/theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/primary_button.dart';
import '../widgets/liquid_glass_background.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() => _isLoadingProfile = true);
      final getProfileUseCase = ref.read(getProfileUseCaseProvider);
      final profile = await getProfileUseCase();

      setState(() {
        _usernameController.text = profile.username ?? '';
        _bioController.text = profile.bio ?? '';
        _profileImageUrl = profile.profileImageUrl;
        _isLoadingProfile = false;
      });
    } catch (e) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Couldn't pick that image. Try another one?")),
        );
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

      // Update profile
      await updateProfileUseCase(
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
      );

      // Reload profile to get updated data
      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        setState(() => _selectedImage = null);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage;
        if (e is AppError) {
          errorMessage = e.getUserMessage();
        } else {
          errorMessage = "Couldn't update your profile. Try again?";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
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
                  Padding(
                    padding: EdgeInsets.only(
                      left: BleyaTheme.contentPadding,
                      right: BleyaTheme.contentPadding,
                      top: BleyaTheme.spacingMD,
                    ),
                    child: Row(
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Icon(
                            CupertinoIcons.chevron_left,
                            size: 28,
                            color: BleyaTheme.foreground,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Edit profile',
                          style:
                              BleyaTheme.headingMedium.copyWith(fontSize: 20),
                        ),
                        const Spacer(),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
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
                  Padding(
                    padding: EdgeInsets.only(
                      left: BleyaTheme.contentPadding,
                      right: BleyaTheme.contentPadding,
                      top: BleyaTheme.spacingMD,
                    ),
                    child: Row(
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Icon(
                            CupertinoIcons.chevron_left,
                            size: 28,
                            color: BleyaTheme.foreground,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Edit profile',
                          style:
                              BleyaTheme.headingMedium.copyWith(fontSize: 20),
                        ),
                        const Spacer(),
                        const SizedBox(width: 44),
                      ],
                    ),
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
                                        backgroundColor: BleyaTheme.greyLight,
                                        fallbackIcon:
                                            CupertinoIcons.person_fill,
                                        fallbackIconColor:
                                            BleyaTheme.mutedForeground,
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
                                        CupertinoIcons.camera_fill,
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
                          // Username Field
                          CupertinoTextField(
                            controller: _usernameController,
                            placeholder: 'Username',
                            padding: const EdgeInsets.all(16),
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
                          const SizedBox(height: 20),
                          // Bio Field
                          CupertinoTextField(
                            controller: _bioController,
                            placeholder: 'Tell us something about yourself',
                            padding: const EdgeInsets.all(16),
                            maxLines: 4,
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
                          const SizedBox(height: 30),
                          // Save Button
                          PrimaryButton(
                            text: 'Save',
                            onPressed: _saveProfile,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
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
