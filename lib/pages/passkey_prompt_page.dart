import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../controllers/auth_controller.dart';
import '../providers/auth_providers.dart';
import '../providers/controller_providers.dart';
import '../utils/app_toast.dart';
import '../widgets/app_navigation_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/liquid_glass_background.dart';

class PasskeyPromptPage extends ConsumerStatefulWidget {
  final bool onboardingFlow;

  const PasskeyPromptPage({
    super.key,
    required this.onboardingFlow,
  });

  @override
  ConsumerState<PasskeyPromptPage> createState() => _PasskeyPromptPageState();
}

class _PasskeyPromptPageState extends ConsumerState<PasskeyPromptPage> {
  Future<void> _registerPasskey() async {
    final result = await ref
        .read(authControllerProvider.notifier)
        .registerPasskey();

    if (result == null || !mounted) {
      return;
    }

    ref.invalidate(authSecurityStatusProvider);

    if (widget.onboardingFlow) {
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }

    AppToast.showSuccess(context, 'Passkey added.');
    Navigator.of(context).pop(true);
  }

  void _skip() {
    if (widget.onboardingFlow) {
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }

    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
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
            const LiquidGlassBackground(),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  AppNavigationBar(
                    title: 'Passkey',
                    showBackButton: !widget.onboardingFlow,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BleyaTheme.contentPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: BleyaTheme.spacingMD),
                          Text(
                            'Finish with a passkey.',
                            style: BleyaTheme.headingMedium.copyWith(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Use Face ID, Touch ID, or your device unlock instead of going back through Apple or Google every time.',
                            style: BleyaTheme.bodyLarge,
                          ),
                          const SizedBox(height: BleyaTheme.spacing2XL),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(BleyaTheme.cardPadding),
                            decoration: BoxDecoration(
                              color: BleyaTheme.primaryLight.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(
                                BleyaTheme.radiusMedium,
                              ),
                              border: Border.all(
                                color: BleyaTheme.primaryMedium,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.lock_shield_fill,
                                      color: BleyaTheme.primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: BleyaTheme.spacingSM),
                                    Text(
                                      'Why add one now?',
                                      style: BleyaTheme.bodyLarge.copyWith(
                                        color: BleyaTheme.foreground,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: BleyaTheme.spacingMD),
                                Text(
                                  'Passkeys stay tied to the device ecosystem you already trust and help prevent account farms from relying on cheap throwaway signups.',
                                  style: BleyaTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          if (authState.errorMessage != null &&
                              authState.errorMessage!.isNotEmpty) ...[
                            const SizedBox(height: BleyaTheme.spacingLG),
                            Text(
                              authState.errorMessage!,
                              style: BleyaTheme.bodyMedium.copyWith(
                                color: BleyaTheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: BleyaTheme.footerPadding,
                      right: BleyaTheme.footerPadding,
                      top: BleyaTheme.footerPadding,
                      bottom: MediaQuery.of(context).padding.bottom +
                          BleyaTheme.footerBottomPadding,
                    ),
                    child: Column(
                      children: [
                        PrimaryButton(
                          text: 'Create Passkey',
                          isLoading: authState.activeAction ==
                              AuthAction.registerPasskey,
                          onPressed: _registerPasskey,
                        ),
                        if (widget.onboardingFlow) ...[
                          const SizedBox(height: BleyaTheme.spacingMD),
                          TextButton(
                            onPressed: authState.isLoading ? null : _skip,
                            child: Text(
                              'Skip for now',
                              style: BleyaTheme.bodyMedium.copyWith(
                                color: BleyaTheme.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
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
