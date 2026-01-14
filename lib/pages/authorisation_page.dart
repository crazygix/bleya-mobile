import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../providers/auth_providers.dart';
import '../utils/app_errors.dart';
import '../widgets/primary_button.dart';
import 'verification_code_page.dart';

class AuthorisationPage extends ConsumerStatefulWidget {
  @override
  AuthorisationPageState createState() => AuthorisationPageState();
}

class AuthorisationPageState extends ConsumerState<AuthorisationPage> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  String? _errorMessage;
  bool _isLoading = false;
  bool _hasPhoneNumber = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      final hasValue = _phoneController.text.trim().isNotEmpty;
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

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = "What's your number?");
      return;
    }

    try {
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });
      final authService = ref.read(authServiceProvider);
      final result =
          await authService.requestCode(phone: _phoneController.text.trim());

      if (mounted) {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => VerificationCodePage(
              phoneNumber: _phoneController.text.trim(),
              codeSentAt: result['codeSentAt'] as String?,
            ),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
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
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
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
                    child: Padding(
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
                          Container(
                            decoration: BoxDecoration(
                              color: BleyaTheme.glassSurface,
                              borderRadius: BorderRadius.circular(
                                  BleyaTheme.radiusMedium),
                              border: Border.all(
                                color: _errorMessage != null
                                    ? BleyaTheme.errorBorder
                                    : (_phoneFocusNode.hasFocus
                                        ? BleyaTheme.primary
                                        : BleyaTheme.border),
                                width: 1,
                              ),
                              boxShadow: BleyaTheme.glassShadow,
                            ),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: BleyaTheme.spacingLG,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.phone,
                                    color: BleyaTheme.mutedForeground,
                                    size: 20,
                                  ),
                                  SizedBox(width: BleyaTheme.spacingMD),
                                  Expanded(
                                    child: CupertinoTextField(
                                      controller: _phoneController,
                                      focusNode: _phoneFocusNode,
                                      placeholder: '+1 (555) 000-0000',
                                      keyboardType: TextInputType.phone,
                                      style: BleyaTheme.bodyLarge.copyWith(
                                        color: BleyaTheme.foreground,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      placeholderStyle:
                                          BleyaTheme.bodyLarge.copyWith(
                                        color: BleyaTheme.mutedForeground
                                            .withValues(alpha: 0.6),
                                      ),
                                      decoration: BoxDecoration(
                                          color: Colors.transparent),
                                      padding: EdgeInsets.symmetric(
                                        vertical: BleyaTheme.spacingLG + 2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            SizedBox(height: BleyaTheme.spacingMD),
                            Text(
                              _errorMessage!,
                              style: BleyaTheme.bodySmall.copyWith(
                                color: BleyaTheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

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
                      text: 'Get code',
                      onPressed: _requestCode,
                      isLoading: _isLoading,
                      isEnabled: _hasPhoneNumber,
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
