import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../platform/app_route.dart';
import '../providers/controller_providers.dart';
import '../widgets/primary_button.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/app_navigation_bar.dart';
import '../widgets/form_field.dart' as bleya;
import 'verification_code_page.dart';

class AuthorisationPage extends ConsumerStatefulWidget {
  @override
  AuthorisationPageState createState() => AuthorisationPageState();
}

class AuthorisationPageState extends ConsumerState<AuthorisationPage> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  bool _hasPhoneNumber = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _phoneFocusNode.requestFocus();
      }
    });
    _phoneController.addListener(() {
      final digits =
          _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      final hasValue = digits.isNotEmpty;
      if (_hasPhoneNumber != hasValue) {
        setState(() {
          _hasPhoneNumber = hasValue;
        });
      }
    });
    _phoneFocusNode.addListener(() {
      setState(() {}); // Update border color on focus change
    });
  }

  String _getPhoneNumber() {
    final digits =
        _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isNotEmpty ? '+$digits' : '';
  }

  String _getPhonePlaceholder(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final countryCode = locale.countryCode ?? 'US';

    // Common phone number formats by country code
    final formats = {
      'US': '1 (555) 000-0000',
      'CA': '1 (555) 000-0000',
      'GB': '44 20 1234 5678',
      'AU': '61 2 1234 5678',
      'DE': '49 30 12345678',
      'FR': '33 1 23 45 67 89',
      'IT': '39 02 1234 5678',
      'ES': '34 91 123 45 67',
      'NL': '31 20 123 4567',
      'BE': '32 2 123 45 67',
      'CH': '41 21 123 45 67',
      'AT': '43 1 2345678',
      'SE': '46 8 123 456 78',
      'NO': '47 21 12 34 56',
      'DK': '45 12 34 56 78',
      'FI': '358 9 1234 567',
      'PL': '48 22 123 45 67',
      'CZ': '420 2 1234 5678',
      'IE': '353 1 234 5678',
      'PT': '351 21 123 4567',
      'GR': '30 21 1234 5678',
      'BR': '55 11 91234-5678',
      'MX': '52 55 1234 5678',
      'AR': '54 11 1234-5678',
      'CL': '56 2 1234 5678',
      'CO': '57 1 234 5678',
      'PE': '51 1 234 5678',
      'ZA': '27 11 123 4567',
      'EG': '20 2 1234 5678',
      'NG': '234 1 234 5678',
      'KE': '254 20 1234567',
      'IN': '91 11 2345 6789',
      'PK': '92 21 12345678',
      'BD': '880 2 1234567',
      'ID': '62 21 1234 5678',
      'TH': '66 2 123 4567',
      'VN': '84 24 1234 5678',
      'PH': '63 2 123 4567',
      'MY': '60 3 1234 5678',
      'SG': '65 6123 4567',
      'HK': '852 2123 4567',
      'TW': '886 2 1234 5678',
      'KR': '82 2-1234-5678',
      'JP': '81 3-1234-5678',
      'CN': '86 10 1234 5678',
      'RU': '7 495 123-45-67',
      'UA': '380 44 123 4567',
      'TR': '90 212 123 45 67',
      'IL': '972 2-123-4567',
      'AE': '971 4 123 4567',
      'SA': '966 11 123 4567',
    };

    return formats[countryCode] ?? formats['US'] ?? '1234567890';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final phoneNumber = _getPhoneNumber();
    final controller = ref.read(authControllerProvider.notifier);

    try {
      final result = await controller.requestCode(phoneNumber);
      if (mounted && result != null) {
        Navigator.of(context).push(
          AppRoute.build(
            builder: (context) => VerificationCodePage(
              phoneNumber: phoneNumber,
              codeSentAt: result.codeSentAt,
            ),
          ),
        );
      }
    } catch (e) {
      // Error is already set in controller state
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: BleyaTheme.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
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
                    title: 'Sign in',
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.symmetric(
                        horizontal: BleyaTheme.contentPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: BleyaTheme.spacingMD),
                          Text(
                            "What's your number?",
                            style: BleyaTheme.headingMedium,
                          ),
                          SizedBox(height: BleyaTheme.spacingMD),
                          Text(
                            "We'll send you a code. Quick and secure.",
                            style: BleyaTheme.bodyLarge,
                          ),
                          SizedBox(height: BleyaTheme.spacing3XL),

                          // Phone Input
                          bleya.FormField(
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            placeholder: _getPhonePlaceholder(context),
                            leadingIcon: CupertinoIcons.phone,
                            errorMessage: authState.errorMessage,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            prefix: Text(
                              '+',
                              style: BleyaTheme.bodyLarge.copyWith(
                                color: BleyaTheme.foreground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          SizedBox(height: BleyaTheme.spacing2XL),

                          // Privacy Message
                          Container(
                            padding: EdgeInsets.all(BleyaTheme.cardPadding),
                            decoration: BoxDecoration(
                              color: BleyaTheme.glassSurface,
                              borderRadius: BorderRadius.circular(
                                  BleyaTheme.radiusMedium),
                              border: Border.all(
                                color: BleyaTheme.border,
                                width: 1,
                              ),
                              boxShadow: BleyaTheme.glassShadow,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.shield,
                                  color: BleyaTheme.primary,
                                  size: 20,
                                ),
                                SizedBox(width: BleyaTheme.spacingMD),
                                Expanded(
                                  child: Text(
                                    'Your number stays private. We never share it with anyone.',
                                    style: BleyaTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.transparent,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.only(
                        left: BleyaTheme.footerPadding,
                        right: BleyaTheme.footerPadding,
                        top: BleyaTheme.footerPadding,
                        bottom: MediaQuery.of(context).padding.bottom +
                            BleyaTheme.footerBottomPadding,
                      ),
                      child: PrimaryButton(
                        text: 'Get code',
                        onPressed: _requestCode,
                        isLoading: authState.isLoading,
                        isEnabled: _hasPhoneNumber,
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
