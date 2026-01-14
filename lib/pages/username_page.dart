import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/theme.dart';
import '../providers/auth_providers.dart';
import '../utils/app_errors.dart';
import '../widgets/primary_button.dart';

class UsernamePage extends ConsumerStatefulWidget {
  const UsernamePage({super.key});

  @override
  UsernamePageState createState() => UsernamePageState();
}

class UsernamePageState extends ConsumerState<UsernamePage> {
  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  String? _errorMessage;
  bool _isLoading = false;
  bool _isChecking = false;
  bool _isValid = false;
  bool _isTouched = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_validateUsername);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_validateUsername);
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  void _validateUsername() {
    final username = _usernameController.text.trim().toLowerCase();
    if (username.length < 3) {
      if (mounted) {
        setState(() {
          _isValid = false;
          _isChecking = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isChecking = true);
    }
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        final isValid = RegExp(r'^[a-z0-9_]+$').hasMatch(username) &&
            username.length >= 3 &&
            username.length <= 30;
        setState(() {
          _isValid = isValid;
          _isChecking = false;
        });
      }
    });
  }

  bool _validateUsernameFormat(String username) {
    if (username.length < 3 || username.length > 30) {
      return false;
    }
    return RegExp(r'^[a-z0-9_]+$').hasMatch(username);
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
        setState(() {
          _errorMessage = "Couldn't pick that image. Try another one?";
        });
      }
    }
  }

  Future<void> _setUsername() async {
    final username = _usernameController.text.trim().toLowerCase();

    if (username.isEmpty) {
      setState(() => _errorMessage = "How should we call you?");
      return;
    }

    if (!_validateUsernameFormat(username)) {
      setState(() => _errorMessage =
          "Keep it simple: 3-30 characters, just letters, numbers, and underscores.");
      return;
    }

    try {
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });

      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);

      // Upload image first if selected
      if (_selectedImage != null) {
        await userService.uploadProfileImage(_selectedImage!);
      }

      await authService.setUsername(username: username);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        if (e is AppError) {
          setState(() => _errorMessage = e.getUserMessage());
        } else {
          setState(() =>
              _errorMessage = "Something went wrong. Let's try that again.");
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getAvatarText() {
    final username = _usernameController.text.trim().toLowerCase();
    if (username.isNotEmpty) {
      return username[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final username = _usernameController.text.trim().toLowerCase();
    final showError = !_isValid && _isTouched && username.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: BleyaTheme.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: BleyaTheme.background,
        body: Stack(
          children: [
            // Liquid Glass Background
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BleyaTheme.primary.withValues(alpha: 0.06),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -60,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BleyaTheme.secondary.withValues(alpha: 0.05),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            // Main Content
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Header with back button
                  Padding(
                    padding: EdgeInsets.only(
                      left: BleyaTheme.contentPadding,
                    ),
                    child: Row(
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () async {
                            final authManager = ref.read(authManagerProvider);
                            await authManager.logout();
                          },
                          child: Icon(
                            CupertinoIcons.chevron_left,
                            color: BleyaTheme.mutedForeground,
                            size: 28,
                          ),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: BleyaTheme.spacingMD),
                          Text(
                            "Pick your handle",
                            style: BleyaTheme.headingMedium.copyWith(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "This is how you'll appear to others.",
                            style: BleyaTheme.bodyLarge,
                          ),
                          const SizedBox(height: 48),

                          // Username Input
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Username',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: BleyaTheme.foreground,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: BleyaTheme.glassSurface
                                      .withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(
                                      BleyaTheme.radiusLarge),
                                  border: Border.all(
                                    color: _errorMessage != null || showError
                                        ? BleyaTheme.errorBorder
                                        : BleyaTheme.border,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: BleyaTheme.foreground
                                          .withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      BleyaTheme.radiusLarge),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 20, sigmaY: 20),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: CupertinoTextField(
                                            controller: _usernameController,
                                            focusNode: _usernameFocusNode,
                                            placeholder: '@username',
                                            keyboardType: TextInputType.text,
                                            textCapitalization:
                                                TextCapitalization.none,
                                            autocorrect: false,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: BleyaTheme.foreground,
                                            ),
                                            placeholderStyle: TextStyle(
                                              color: BleyaTheme.mutedForeground
                                                  .withValues(alpha: 0.6),
                                            ),
                                            decoration: BoxDecoration(
                                                color: Colors.transparent),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 18,
                                            ),
                                            onChanged: (_) {
                                              setState(() => _isTouched = true);
                                            },
                                          ),
                                        ),
                                        if (_isChecking)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 16),
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CupertinoActivityIndicator(
                                                radius: 8,
                                              ),
                                            ),
                                          )
                                        else if (_isValid)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 16),
                                            child: Icon(
                                              CupertinoIcons.check_mark_circled,
                                              color: BleyaTheme.success,
                                              size: 20,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 20,
                                child: showError
                                    ? Text(
                                        username.length < 3
                                            ? 'Keep it simple: at least 3 characters, just letters, numbers, and underscores.'
                                            : 'Just letters, numbers, and underscores.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: BleyaTheme.mutedForeground,
                                        ),
                                      )
                                    : _isValid
                                        ? Text(
                                            '@$username is available!',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: BleyaTheme.success,
                                            ),
                                          )
                                        : SizedBox.shrink(),
                              ),
                            ],
                          ),

                          const SizedBox(height: 48),

                          // Avatar Hero Preview
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _isLoading ? null : _pickImage,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 128,
                                        height: 128,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: username.isNotEmpty
                                              ? BleyaTheme.skywashGradient
                                              : null,
                                          color: username.isEmpty
                                              ? BleyaTheme.border
                                              : null,
                                          boxShadow: username.isNotEmpty
                                              ? [
                                                  BoxShadow(
                                                    color: BleyaTheme.primary
                                                        .withValues(
                                                            alpha: 0.25),
                                                    blurRadius: 32,
                                                    offset: Offset(0, 8),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: _selectedImage != null
                                            ? ClipOval(
                                                child: Image.file(
                                                  _selectedImage!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Center(
                                                      child: Text(
                                                        _getAvatarText(),
                                                        style: TextStyle(
                                                          fontSize: 48,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              )
                                            : Center(
                                                child: Text(
                                                  _getAvatarText(),
                                                  style: TextStyle(
                                                    fontSize: 48,
                                                    fontWeight: FontWeight.w500,
                                                    color: username.isNotEmpty
                                                        ? Colors.white
                                                        : BleyaTheme
                                                            .mutedForeground,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: BleyaTheme.foreground
                                                    .withValues(alpha: 0.1),
                                                blurRadius: 8,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            CupertinoIcons.camera_fill,
                                            color: BleyaTheme.mutedForeground,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  '@${username.isNotEmpty ? username : "username"}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: username.isNotEmpty
                                        ? BleyaTheme.foreground
                                        : BleyaTheme.border,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your digital identity',
                                  style: BleyaTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 24),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: BleyaTheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Footer Button
                  Padding(
                    padding: EdgeInsets.only(
                      left: BleyaTheme.footerPadding,
                      right: BleyaTheme.footerPadding,
                      top: BleyaTheme.footerPadding,
                      bottom: MediaQuery.of(context).padding.bottom +
                          BleyaTheme.footerBottomPadding,
                    ),
                    child: PrimaryButton(
                      text: 'Start Exploring',
                      onPressed: _setUsername,
                      isLoading: _isLoading,
                      isEnabled: _isValid,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
