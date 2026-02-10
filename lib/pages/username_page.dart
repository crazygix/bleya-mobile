import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/theme.dart';
import '../providers/auth_providers.dart';
import '../providers/controller_providers.dart';
import '../widgets/primary_button.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/app_navigation_bar.dart';
import '../widgets/form_field.dart' as bleya;

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

  String? _getErrorMessage(dynamic usernameState, String username,
      bool isUnavailable, bool showError) {
    if (usernameState.errorMessage != null) {
      return usernameState.errorMessage;
    } else if (isUnavailable) {
      return "That username's taken. Try another one?";
    } else if (showError) {
      return username.length < 3
          ? 'Keep it simple: at least 3 characters, just letters, numbers, and underscores.'
          : 'Just letters, numbers, and underscores.';
    }
    return null;
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
            LiquidGlassBackground(),

            // Main Content
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // iOS-style Navigation Bar
                  AppNavigationBar(
                    onBackPressed: () async {
                      final authManager = ref.read(authManagerProvider);
                      await authManager.logout();
                    },
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
                          bleya.FormField(
                            controller: _usernameController,
                            focusNode: _usernameFocusNode,
                            placeholder: 'username',
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            errorMessage: _getErrorMessage(
                              usernameState,
                              username,
                              isUnavailable,
                              showError,
                            ),
                            showSuccess:
                                usernameState.isValid && username.isNotEmpty,
                            successMessage: 'Looks good!',
                            helperText: !usernameState.isValid &&
                                    !_isTouched &&
                                    username.isEmpty
                                ? 'At least 3 characters, just letters, numbers, and underscores'
                                : null,
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
                                              ? BleyaTheme.primaryLight
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
                                            CupertinoIcons.camera,
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
                                  username.isNotEmpty ? username : 'username',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: BleyaTheme.foreground,
                                  ),
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
