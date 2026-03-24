import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../controllers/auth_controller.dart';
import '../domain/entities/auth_result.dart';
import '../platform/app_button.dart';
import '../platform/app_route.dart';
import '../platform/ui_platform.dart';
import '../providers/auth_providers.dart';
import '../providers/controller_providers.dart';
import '../utils/app_toast.dart';
import '../utils/passkey_onboarding.dart';
import '../widgets/app_navigation_bar.dart';
import '../widgets/app_spinner.dart';
import '../widgets/liquid_glass_background.dart';
import 'username_page.dart';

const double _providerButtonHeight = BleyaTheme.buttonHeight;
const double _providerFontSize = 17;

class AuthorisationPage extends ConsumerStatefulWidget {
  const AuthorisationPage({super.key});

  @override
  ConsumerState<AuthorisationPage> createState() => _AuthorisationPageState();
}

class _AuthorisationPageState extends ConsumerState<AuthorisationPage> {
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
    await Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _handleNavigation(
    AuthNavigationRequest request,
  ) async {
    if (!mounted) return;

    ref.read(authControllerProvider.notifier).consumeNavigation();

    switch (request.target) {
      case AuthNavigationTarget.username:
        await Navigator.of(context).pushReplacement(
          AppRoute.build(
            builder: (context) => UsernamePage(
              showPasskeyPromptAfterCompletion:
                  request.showPasskeyPromptAfterCompletion,
            ),
          ),
        );
        return;
      case AuthNavigationTarget.passkeyPrompt:
        await _completePasskeyOnboarding();
        return;
      case AuthNavigationTarget.home:
        await Navigator.of(context).pushReplacementNamed('/home');
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final appleAvailability = ref.watch(appleSignInAvailableProvider);
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final request = next.navigationRequest;
      if (request == null || identical(request, previous?.navigationRequest)) {
        return;
      }

      _handleNavigation(request);
    });

    final platformPrimary = isIosPlatform(context)
        ? [AuthProvider.apple, AuthProvider.google]
        : [AuthProvider.google, AuthProvider.apple];

    final showApple = appleAvailability.valueOrNull ?? true;

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
                    showBackButton: true,
                    title: null,
                    onBackPressed: () async {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BleyaTheme.contentPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: BleyaTheme.spacingMD),
                          Text(
                            'Connect in seconds',
                            style: BleyaTheme.headingMedium.copyWith(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Use your Apple or Google account.\nFast, simple, and secure.',
                            style: BleyaTheme.bodyLarge,
                          ),
                          const Spacer(),
                          if (authState.errorMessage != null &&
                              authState.errorMessage!.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(
                                BleyaTheme.cardPadding,
                              ),
                              decoration: BoxDecoration(
                                color: BleyaTheme.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(
                                  BleyaTheme.radiusMedium,
                                ),
                                border: Border.all(
                                  color:
                                      BleyaTheme.error.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                authState.errorMessage!,
                                style: BleyaTheme.bodyMedium.copyWith(
                                  color: BleyaTheme.error,
                                ),
                              ),
                            ),
                            const SizedBox(height: BleyaTheme.spacingLG),
                          ],
                          for (final provider in platformPrimary) ...[
                            if (provider == AuthProvider.apple &&
                                showApple) ...[
                              _AppleButton(
                                isLoading: authState.activeAction ==
                                    AuthAction.signInWithApple,
                                disabled: authState.isLoading,
                                onPressed: () => ref
                                    .read(authControllerProvider.notifier)
                                    .signInWithApple(),
                              ),
                              const SizedBox(height: BleyaTheme.spacingMD),
                            ],
                            if (provider == AuthProvider.google) ...[
                              _GoogleButton(
                                text: 'Continue with Google',
                                isLoading: authState.activeAction ==
                                    AuthAction.signInWithGoogle,
                                disabled: authState.isLoading,
                                onPressed: () => ref
                                    .read(authControllerProvider.notifier)
                                    .signInWithGoogle(),
                              ),
                              const SizedBox(height: BleyaTheme.spacingMD),
                            ],
                          ],
                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom +
                                BleyaTheme.spacingLG,
                          ),
                        ],
                      ),
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

class _GoogleLogo extends StatelessWidget {
  final double size;

  const _GoogleLogo() : size = 18;
  const _GoogleLogo.sized(this.size);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.18;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const degree = 3.1415926535897932 / 180;

    canvas.drawArc(rect, 300 * degree, 70 * degree, false, arcPaint(_blue));
    canvas.drawArc(rect, 45 * degree, 95 * degree, false, arcPaint(_green));
    canvas.drawArc(rect, 140 * degree, 75 * degree, false, arcPaint(_yellow));
    canvas.drawArc(rect, 215 * degree, 85 * degree, false, arcPaint(_red));

    final barPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(
      Offset(size.width * 0.54, size.height * 0.5),
      Offset(size.width * 0.92, size.height * 0.5),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final bool disabled;
  final String text;

  const _GoogleButton({
    required this.onPressed,
    required this.isLoading,
    required this.disabled,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return _ProviderButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      disabled: disabled,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1F1F1F),
      borderColor: const Color(0xFFDADCE0),
      indicatorColor: const Color(0xFF1F1F1F),
      leading: const _GoogleLogo.sized(18),
    );
  }
}

class _AppleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final bool disabled;

  const _AppleButton({
    required this.onPressed,
    required this.isLoading,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return _ProviderButton(
      text: 'Continue with Apple',
      onPressed: onPressed,
      isLoading: isLoading,
      disabled: disabled,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      borderColor: Colors.transparent,
      indicatorColor: Colors.white,
      leading: const _AppleLogo(),
    );
  }
}

class _AppleLogo extends StatelessWidget {
  const _AppleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 22,
      child: CustomPaint(
        painter: _AppleLogoPainter(color: Colors.white),
      ),
    );
  }
}

class _AppleLogoPainter extends CustomPainter {
  final Color color;

  const _AppleLogoPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawPath(_applePath(size.width, size.height), paint);
  }

  static Path _applePath(double w, double h) {
    return Path()
      ..moveTo(w * .50779, h * .28732)
      ..cubicTo(
        w * .4593,
        h * .28732,
        w * .38424,
        h * .24241,
        w * .30519,
        h * .24404,
      )
      ..cubicTo(
        w * .2009,
        h * .24512,
        w * .10525,
        h * .29328,
        w * .05145,
        h * .36957,
      )
      ..cubicTo(
        w * -.05683,
        h * .5227,
        w * .02355,
        h * .74888,
        w * .12916,
        h * .87333,
      )
      ..cubicTo(
        w * .18097,
        h * .93394,
        w * .24209,
        h * 1.00211,
        w * .32313,
        h * .99995,
      )
      ..cubicTo(
        w * .40084,
        h * .99724,
        w * .43007,
        h * .95883,
        w * .52439,
        h * .95883,
      )
      ..cubicTo(
        w * .61805,
        h * .95883,
        w * .64462,
        h * .99995,
        w * .72699,
        h * .99833,
      )
      ..cubicTo(
        w * .81069,
        h * .99724,
        w * .86383,
        h * .93664,
        w * .91498,
        h * .8755,
      )
      ..cubicTo(
        w * .97409,
        h * .80515,
        w * .99867,
        h * .73698,
        w * 1,
        h * .73319,
      )
      ..cubicTo(
        w * .99801,
        h * .73265,
        w * .83726,
        h * .68233,
        w * .83526,
        h * .53082,
      )
      ..cubicTo(
        w * .83394,
        h * .4042,
        w * .96214,
        h * .3436,
        w * .96812,
        h * .34089,
      )
      ..cubicTo(
        w * .89505,
        h * .25378,
        w * .78279,
        h * .24404,
        w * .7436,
        h * .24187,
      )
      ..cubicTo(
        w * .6413,
        h * .23538,
        w * .55561,
        h * .28732,
        w * .50779,
        h * .28732,
      )
      ..close()
      ..moveTo(w * .68049, h * .15962)
      ..cubicTo(w * .72367, h * .11742, w * .75223, h * .05844, w * .74426, 0)
      ..cubicTo(
        w * .68249,
        h * .00216,
        w * .60809,
        h * .03355,
        w * .56359,
        h * .07575,
      )
      ..cubicTo(
        w * .52373,
        h * .11309,
        w * .48919,
        h * .17315,
        w * .49849,
        h * .23051,
      )
      ..cubicTo(
        w * .56691,
        h * .23484,
        w * .63732,
        h * .20183,
        w * .68049,
        h * .15962,
      )
      ..close();
  }

  @override
  bool shouldRepaint(covariant _AppleLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ProviderButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool disabled;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final Color indicatorColor;
  final Widget leading;

  const _ProviderButton({
    required this.text,
    required this.onPressed,
    required this.isLoading,
    required this.disabled,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.indicatorColor,
    required this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: disabled,
      child: Opacity(
        opacity: disabled ? 0.7 : 1,
        child: SizedBox(
          width: double.infinity,
          height: _providerButtonHeight,
          child: AppButton(
            onPressed: disabled ? null : onPressed,
            padding: EdgeInsets.zero,
            minimumSize: const Size.fromHeight(_providerButtonHeight),
            variant: AppButtonVariant.plain,
            borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: _providerButtonHeight,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(
                      BleyaTheme.radiusMedium,
                    ),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Center(
                            child: leading,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            style: BleyaTheme.buttonText.copyWith(
                              color: foregroundColor,
                              fontSize: _providerFontSize,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isLoading)
                  Positioned(
                    left: 18,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: AppSpinner(
                        size: 18,
                        color: indicatorColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
