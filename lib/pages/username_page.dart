import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/theme.dart';
import '../controllers/username_controller.dart';
import '../providers/auth_providers.dart';
import '../providers/controller_providers.dart';
import '../providers/profile_providers.dart';
import '../utils/app_toast.dart';
import '../utils/lowercase_text_input_formatter.dart';
import '../utils/navigation.dart';
import '../utils/passkey_onboarding.dart';
import '../widgets/primary_button.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/app_navigation_bar.dart';
import '../widgets/form_field.dart' as bleya;

class UsernamePage extends ConsumerStatefulWidget {
  final bool showPasskeyPromptAfterCompletion;

  const UsernamePage({
    super.key,
    this.showPasskeyPromptAfterCompletion = false,
  });

  @override
  UsernamePageState createState() => UsernamePageState();
}

class UsernamePageState extends ConsumerState<UsernamePage> {
  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  bool _isTouched = false;

  Future<void> _completePasskeyOnboarding() async {
    final controller = ref.read(authControllerProvider.notifier);

    await maybeRegisterOnboardingPasskey(
      registerPasskey: controller.registerPasskey,
      invalidateSecurityStatus: () =>
          ref.invalidate(authSecurityStatusProvider),
      readAuthState: () => ref.read(authControllerProvider),
      clearAuthError: controller.clearError,
      showError: (message) => AppToast.showError(context, message),
    );

    if (!mounted) return;
    await showHomeAsOnlyRoute(Navigator.of(context));
  }

  /// Leaving this page signs out: the account is signed in but has no
  /// username yet.
  Future<void> _signOut() {
    return ref.read(authManagerProvider).logout();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(usernameControllerProvider.notifier).resetTransientUiState();
    });
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
      await controller.submitUsername(
        username,
        showPasskeyPromptAfterCompletion:
            widget.showPasskeyPromptAfterCompletion,
      );
    } catch (e) {
      // Error is already set in controller state
    }
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
    ref.listen<UsernameState>(usernameControllerProvider, (previous, next) {
      final request = next.completionRequest;
      final profile = next.completedProfile;
      if (request == null ||
          profile == null ||
          identical(request, previous?.completionRequest)) {
        return;
      }

      ref.read(profileProvider.notifier).setProfile(profile);
      ref.read(usernameControllerProvider.notifier).consumeCompletion();

      switch (request.target) {
        case UsernameCompletionTarget.passkeyPrompt:
          _completePasskeyOnboarding();
          return;
        case UsernameCompletionTarget.home:
          showHomeAsOnlyRoute(Navigator.of(context));
          return;
      }
    });

    final username = _usernameController.text.trim().toLowerCase();
    final isUnavailable = usernameState.hasCheckedAvailability &&
        !usernameState.isValid &&
        username.isNotEmpty &&
        RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(username);
    final showError = !usernameState.isValid &&
        _isTouched &&
        username.isNotEmpty &&
        !isUnavailable;

    // System back signs out too, like the back button, instead of uncovering
    // the intro while signed in.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _signOut();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                      title: 'Username',
                      onBackPressed: _signOut,
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
                              textCapitalization: TextCapitalization.none,
                              inputFormatters: const [
                                LowercaseTextInputFormatter(),
                              ],
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.username],
                              autocorrect: false,
                              enableSuggestions: false,
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
                                            color: BleyaTheme.primaryLight,
                                          ),
                                          child: usernameState.selectedImage !=
                                                  null
                                              ? ClipOval(
                                                  child: Image.file(
                                                    usernameState
                                                        .selectedImage!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return Center(
                                                        child: Icon(
                                                          CupertinoIcons.person,
                                                          size: 48,
                                                          color: BleyaTheme
                                                              .primaryDark,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                )
                                              : Center(
                                                  child: Icon(
                                                    CupertinoIcons.person,
                                                    size: 48,
                                                    color:
                                                        BleyaTheme.primaryDark,
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
      ),
    );
  }
}
