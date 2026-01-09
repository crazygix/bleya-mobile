import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../providers/auth_providers.dart';
import '../utils/app_errors.dart';
import '../widgets/primary_button.dart';
import 'username_page.dart';

class VerificationCodePage extends ConsumerStatefulWidget {
  final String phoneNumber;

  const VerificationCodePage({
    super.key,
    required this.phoneNumber,
  });

  @override
  VerificationCodePageState createState() => VerificationCodePageState();
}

class VerificationCodePageState extends ConsumerState<VerificationCodePage> {
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  String? _errorMessage;
  bool _isLoading = false;
  final List<bool> _hasValue = List.generate(6, (_) => false);

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _codeControllers.length; i++) {
      final index = i;
      _codeControllers[i].addListener(() {
        if (!mounted) return;
        final hasValue = _codeControllers[index].text.isNotEmpty;
        if (_hasValue[index] != hasValue) {
          setState(() {
            _hasValue[index] = hasValue;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _handleCodeChange(int index, String value) {
    if (value.length > 1) {
      // Handle paste
      final pastedCode = value.substring(0, 6).split('');
      for (int i = 0; i < pastedCode.length && i < 6; i++) {
        if (i < _codeControllers.length) {
          _codeControllers[i].text = pastedCode[i];
          _hasValue[i] = pastedCode[i].isNotEmpty;
        }
      }
      setState(() {});
      final nextIndex = pastedCode.length < 6 ? pastedCode.length : 5;
      if (nextIndex < _focusNodes.length) {
        _focusNodes[nextIndex].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty && !RegExp(r'[0-9]').hasMatch(value)) {
      _codeControllers[index].clear();
      setState(() {
        _hasValue[index] = false;
      });
      return;
    }

    // Update hasValue state
    setState(() {
      _hasValue[index] = value.isNotEmpty;
    });

    // Handle backspace - move to previous field if current is empty
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      // Select all text in previous field for easy deletion
      _codeControllers[index - 1].selection = TextSelection(
        baseOffset: 0,
        extentOffset: _codeControllers[index - 1].text.length,
      );
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
  }


  String _getCode() {
    return _codeControllers.map((c) => c.text).join();
  }

  bool _isCodeComplete() {
    return _codeControllers.every((c) => c.text.isNotEmpty);
  }

  Future<void> _verifyCode() async {
    final code = _getCode();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete verification code');
      return;
    }

    try {
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });
      final authService = ref.read(authServiceProvider);
      final result = await authService.verifyCode(
        phone: widget.phoneNumber,
        code: code,
      );
      // Update token provider state so interceptor starts injecting Authorization
      final token = result['token'] as String;
      final requiresUsername = result['requiresUsername'] as bool? ?? false;
      ref.read(tokenProvider.notifier).state = token;

      if (mounted) {
        if (requiresUsername) {
          // Navigate to username page if username is required
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (context) => UsernamePage(),
            ),
          );
        } else {
          // Navigate to home if username is already set
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        if (e is AppError) {
          setState(() => _errorMessage = e.getUserMessage());
        } else {
          setState(() => _errorMessage = 'An unexpected error occurred. Please try again.');
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
                          'Enter the Code',
                          style: BleyaTheme.headingMedium.copyWith(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "We sent a 6-digit code to your phone.",
                          style: BleyaTheme.bodyLarge,
                        ),
                        const SizedBox(height: 48),

                        // 6-Digit Code Inputs
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 48,
                              height: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _hasValue[index]
                                      ? BleyaTheme.primary.withValues(alpha: 0.05)
                                      : BleyaTheme.glassSurface.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
                                  border: Border.all(
                                    color: _hasValue[index]
                                        ? BleyaTheme.primary
                                        : BleyaTheme.border,
                                    width: 1,
                                  ),
                                  boxShadow: _hasValue[index]
                                      ? [
                                          BoxShadow(
                                            color: BleyaTheme.primary.withValues(alpha: 0.1),
                                            blurRadius: 3,
                                            offset: Offset(0, 0),
                                          ),
                                        ]
                                      : BleyaTheme.glassShadow,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                    child: CupertinoTextField(
                                      controller: _codeControllers[index],
                                      focusNode: _focusNodes[index],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      maxLength: 1,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: _hasValue[index]
                                            ? BleyaTheme.primary
                                            : BleyaTheme.foreground,
                                      ),
                                      decoration: BoxDecoration(color: Colors.transparent),
                                      onChanged: (value) => _handleCodeChange(index, value),
                                      onSubmitted: (_) {
                                        if (index < 5) {
                                          _focusNodes[index + 1].requestFocus();
                                        } else {
                                          _verifyCode();
                                        }
                                      },
                                      onTap: () {
                                        _codeControllers[index].selection = TextSelection(
                                          baseOffset: 0,
                                          extentOffset: _codeControllers[index].text.length,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.red.shade500,
                            ),
                          ),
                        ],

                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            'Code expires in 4:59',
                            style: BleyaTheme.bodySmall.copyWith(
                              color: BleyaTheme.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer Buttons
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
                        text: 'Verify',
                        onPressed: _verifyCode,
                        isLoading: _isLoading,
                        isEnabled: _isCodeComplete(),
                      ),
                      SizedBox(height: BleyaTheme.spacingLG),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(
                          "Didn't get it? Resend",
                          style: TextStyle(
                            color: BleyaTheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
