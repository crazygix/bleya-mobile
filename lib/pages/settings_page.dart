import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_providers.dart';
import '../config/environment.dart';

class SettingsPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isLoadingProfile = true;
  String? _profileImageUrl;
  File? _selectedImage;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() => _isLoadingProfile = true);
      final userService = ref.read(userServiceProvider);
      final profile = await userService.getProfile();

      setState(() {
        _userData = profile;
        _usernameController.text = profile['username'] ?? '';
        _bioController.text = profile['bio'] ?? '';
        _profileImageUrl = profile['profileImageUrl'];
        _isLoadingProfile = false;
      });
    } catch (e) {
      setState(() => _isLoadingProfile = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
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
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  String? _getImageUrl() {
    if (_selectedImage != null) {
      return _selectedImage!.path;
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      // Construct full URL - profileImageUrl is like "/uploads/profiles/..."
      final baseUrl = EnvironmentConfig.baseUrl.replaceAll('/api', '');
      return '$baseUrl$_profileImageUrl';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userService = ref.read(userServiceProvider);

      // Upload image first if selected
      if (_selectedImage != null) {
        await userService.uploadProfileImage(_selectedImage!);
      }

      // Update profile
      await userService.updateProfile(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
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
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
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
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _getImageUrl() != null
                            ? (_selectedImage != null
                                ? FileImage(_selectedImage!)
                                : NetworkImage(_getImageUrl()!)
                                    as ImageProvider)
                            : null,
                        child: _getImageUrl() == null
                            ? const Icon(Icons.person,
                                size: 60, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
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
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.none,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Bio Field
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'About Me',
                  hintText: 'Tell us something about yourself',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info),
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 30),
              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Profile'),
              ),
              if (_userData != null) ...[
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 10),
                Text(
                  'Phone: ${_userData!['phoneNumber'] ?? 'N/A'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
