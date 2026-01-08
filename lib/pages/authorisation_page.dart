import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../providers/auth_providers.dart';
import '../utils/app_errors.dart';
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
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }

    try {
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });
      final authService = ref.read(authServiceProvider);
      await authService.requestCode(phone: _phoneController.text.trim());

      if (mounted) {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => VerificationCodePage(
              phoneNumber: _phoneController.text.trim(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (e is AppError) {
          setState(() => _errorMessage = e.getUserMessage());
        } else {
          setState(() => _errorMessage =
              'An unexpected error occurred. Please try again.');
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
    return Scaffold(
      backgroundColor: BleyaTheme.background,
      body: SafeArea(
        child: Stack(
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
            Column(
              children: [
                // Header with back button
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 48, bottom: 16),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            CupertinoIcons.chevron_left,
                            color: BleyaTheme.mutedForeground,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'Enter Your Number',
                          style: BleyaTheme.headingMedium.copyWith(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "We'll send you a code. Quick and secure.",
                          style: BleyaTheme.bodyLarge,
                        ),
                        const SizedBox(height: 48),

                        // Phone Input
                        Container(
                          decoration: BoxDecoration(
                            color:
                                BleyaTheme.glassSurface.withValues(alpha: 0.8),
                            borderRadius:
                                BorderRadius.circular(BleyaTheme.radiusLarge),
                            border: Border.all(
                              color: _errorMessage != null
                                  ? Colors.red.shade400
                                  : BleyaTheme.border,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(BleyaTheme.radiusLarge),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.phone,
                                      color: BleyaTheme.mutedForeground,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CupertinoTextField(
                                        controller: _phoneController,
                                        focusNode: _phoneFocusNode,
                                        placeholder: '+1 (555) 000-0000',
                                        keyboardType: TextInputType.phone,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                          color: BleyaTheme.foreground,
                                        ),
                                        placeholderStyle: TextStyle(
                                          color: BleyaTheme.mutedForeground
                                              .withValues(alpha: 0.6),
                                        ),
                                        decoration: BoxDecoration(
                                            color: Colors.transparent),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.red.shade500,
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Privacy Message
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                BleyaTheme.glassSurface.withValues(alpha: 0.7),
                            borderRadius:
                                BorderRadius.circular(BleyaTheme.radiusMedium),
                            border: Border.all(
                              color: BleyaTheme.border,
                              width: 1,
                            ),
                            boxShadow: BleyaTheme.glassShadow,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                CupertinoIcons.shield,
                                color: BleyaTheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your number stays private. We never share it with anyone.',
                                  style: BleyaTheme.bodySmall.copyWith(
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
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
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: BleyaTheme.background.withValues(alpha: 0.8),
                    border: Border(
                      top: BorderSide(
                        color: BleyaTheme.border.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: Colors.transparent,
                      onPressed: _isLoading ? null : _requestCode,
                      disabledColor: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _isLoading || !_hasPhoneNumber
                              ? null
                              : BleyaTheme.skywashGradient,
                          color: _isLoading || !_hasPhoneNumber
                              ? BleyaTheme.mutedForeground
                                  .withValues(alpha: 0.3)
                              : null,
                          borderRadius:
                              BorderRadius.circular(BleyaTheme.radiusLarge),
                          boxShadow: _isLoading || !_hasPhoneNumber
                              ? null
                              : BleyaTheme.primaryShadow,
                        ),
                        child: Center(
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CupertinoActivityIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Send Code',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
