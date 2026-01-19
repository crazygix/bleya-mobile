import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/theme.dart';
import '../providers/auth_providers.dart';
import '../providers/controller_providers.dart';
import '../widgets/primary_button.dart';

class UsernamePage extends ConsumerStatefulWidget {
  const UsernamePage({super.key});

  @override
  UsernamePageState createState() => UsernamePageState();
}

class UsernamePageState extends ConsumerState<UsernamePage> {
  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  bool _isTouched = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final username = _usernameController.text.trim().toLowerCase();
    final controller = ref.read(usernameControllerProvider.notifier);
    controller.validateUsername(username);
    if (!_isTouched) {
      setState(() => _isTouched = true);
    }
    controller.clearError();
    controller.resetAvailabilityCheck();
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
        final controller = ref.read(usernameControllerProvider.notifier);
        controller.setSelectedImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        final controller = ref.read(usernameControllerProvider.notifier);
        controller.setError("Couldn't pick that image. Try another one?");
      }
    }
  }

  Future<void> _setUsername() async {
    final username = _usernameController.text.trim().toLowerCase();
    final controller = ref.read(usernameControllerProvider.notifier);

    try {
      await controller.setUsername(username);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      // Error is already set in controller state
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
    final usernameState = ref.watch(usernameControllerProvider);
    final username = _usernameController.text.trim().toLowerCase();
    final isUnavailable = usernameState.hasCheckedAvailability &&
        !usernameState.isValid &&
        username.isNotEmpty &&
        RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(username);
    final showError = !usernameState.isValid &&
        _isTouched &&
        username.isNotEmpty &&
        !isUnavailable;

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
                  // iOS-style Navigation Bar (44pt height per HIG)
                  Container(
                    height: 44.0, // HIG standard navigation bar height
                    padding: EdgeInsets.symmetric(
                      horizontal: BleyaTheme.contentPadding,
                    ),
                    child: Row(
                      children: [
                        // Back button with proper touch target (44x44pt minimum)
                        SizedBox(
                          width: BleyaTheme
                              .iconContainerSize, // 44pt minimum touch target
                          height: BleyaTheme.iconContainerSize,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: () async {
                              final authManager = ref.read(authManagerProvider);
                              await authManager.logout();
                            },
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Icon(
                                CupertinoIcons.chevron_left,
                                color: BleyaTheme.mutedForeground,
                                size: 28,
                              ),
                            ),
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
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  'Username',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: BleyaTheme.foreground,
                                  ),
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
                                    color: usernameState.errorMessage != null ||
                                            showError ||
                                            isUnavailable
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
                                                  .withValues(alpha: 0.8),
                                            ),
                                            decoration: BoxDecoration(
                                                color: Colors.transparent),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 18,
                                            ),
                                            onChanged: (_) {
                                              // Handled by _onUsernameChanged listener
                                            },
                                          ),
                                        ),
                                        if (usernameState.isChecking)
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
                                        else if (usernameState.isValid)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 16),
                                            child: Icon(
                                              CupertinoIcons.check_mark_circled,
                                              color: BleyaTheme.success,
                                              size: 20,
                                            ),
                                          )
                                        else if (isUnavailable)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 16),
                                            child: Icon(
                                              CupertinoIcons.xmark_circle_fill,
                                              color: BleyaTheme.error,
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
                                child: Builder(
                                  builder: (context) {
                                    String? helperText;
                                    Color helperColor =
                                        BleyaTheme.mutedForeground;

                                    if (usernameState.errorMessage != null) {
                                      helperText = usernameState.errorMessage;
                                      helperColor = BleyaTheme.error;
                                    } else if (isUnavailable) {
                                      helperText =
                                          "That username's taken. Try another one?";
                                      helperColor = BleyaTheme.error;
                                    } else if (showError) {
                                      helperText = username.length < 3
                                          ? 'Keep it simple: at least 3 characters, just letters, numbers, and underscores.'
                                          : 'Just letters, numbers, and underscores.';
                                      helperColor = BleyaTheme.mutedForeground;
                                    } else if (usernameState.isValid &&
                                        username.isNotEmpty) {
                                      helperText = 'Looks good!';
                                      helperColor = BleyaTheme.success;
                                    }

                                    if (helperText == null) {
                                      return const SizedBox.shrink();
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Text(
                                        helperText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              helperColor == BleyaTheme.success
                                                  ? FontWeight.w500
                                                  : FontWeight.normal,
                                          color: helperColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 48),

                          // Avatar Hero Preview
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: usernameState.isLoading
                                      ? null
                                      : _pickImage,
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
                                        child: usernameState.selectedImage !=
                                                null
                                            ? ClipOval(
                                                child: Image.file(
                                                  usernameState.selectedImage!,
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
                                    color: BleyaTheme.foreground,
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
                      isLoading: usernameState.isLoading,
                      isEnabled: usernameState.isValid,
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
