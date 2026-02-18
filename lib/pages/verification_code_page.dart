import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../providers/auth_providers.dart';
import '../providers/controller_providers.dart';
import '../widgets/primary_button.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/app_navigation_bar.dart';
import 'username_page.dart';

class VerificationCodePage extends ConsumerStatefulWidget {
  final String phoneNumber;
  final int? codeSentAt;

  const VerificationCodePage({
    super.key,
    required this.phoneNumber,
    this.codeSentAt,
  });

  @override
  VerificationCodePageState createState() => VerificationCodePageState();
}

class VerificationCodePageState extends ConsumerState<VerificationCodePage> {
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<bool> _hasValue = List.generate(6, (_) => false);

  DateTime? _codeSentAt;
  int _resendRemainingSeconds = 60;
  Timer? _countdownTimer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    if (widget.codeSentAt != null) {
      _updateCodeSentTime(widget.codeSentAt);
    } else {
      _codeSentAt = DateTime.now();
      _resendRemainingSeconds = 60;
      _startCountdown();
    }
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

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();

      setState(() {
        // Update resend cooldown (1 minute)
        if (_codeSentAt != null) {
          final resendElapsed = now.difference(_codeSentAt!).inSeconds;
          _resendRemainingSeconds = (60 - resendElapsed).clamp(0, 60);

          if (_resendRemainingSeconds <= 0) {
            timer.cancel();
          }
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _updateCodeSentTime(int? codeSentAtTimestamp) {
    if (codeSentAtTimestamp != null) {
      _codeSentAt = DateTime.fromMillisecondsSinceEpoch(codeSentAtTimestamp);
      final now = DateTime.now();

      // Calculate initial remaining time for resend cooldown
      final resendElapsed = now.difference(_codeSentAt!).inSeconds;
      _resendRemainingSeconds = (60 - resendElapsed).clamp(0, 60);

      _startCountdown();
    } else {
      // Fallback if no timestamp provided
      _codeSentAt = DateTime.now();
      _resendRemainingSeconds = 60;
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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

    // Handle backspace - clear current field and move to previous
    if (value.isEmpty) {
      if (index > 0) {
        // Clear previous field and move focus there
        _codeControllers[index - 1].clear();
        setState(() {
          _hasValue[index - 1] = false;
        });
        _focusNodes[index - 1].requestFocus();
      }
    } else {
      // Move to next field when digit is entered
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      }
    }
  }

  String _getCode() {
    return _codeControllers.map((c) => c.text).join();
  }

  bool _isCodeComplete() {
    return _codeControllers.every((c) => c.text.isNotEmpty);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _handleResend() async {
    if (_resendRemainingSeconds > 0 || _isResending) return;

    try {
      setState(() => _isResending = true);
      final controller = ref.read(authControllerProvider.notifier);
      final result = await controller.resendCode(widget.phoneNumber);
      _updateCodeSentTime(result.codeSentAt);
      if (mounted) {
        setState(() => _isResending = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _getCode();
    final controller = ref.read(authControllerProvider.notifier);

    try {
      final result = await controller.verifyCode(
        phone: widget.phoneNumber,
        code: code,
      );

      if (result != null && mounted) {
        // Update token provider state so interceptor starts injecting Authorization
        ref.read(tokenProvider.notifier).state = result.token;

        if (result.requiresUsername) {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (context) => UsernamePage(),
            ),
          );
        } else {
          Navigator.of(context).pushReplacementNamed('/home');
        }
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
                    title: 'Verification',
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
                            "Confirm it's you",
                            style: BleyaTheme.headingMedium,
                          ),
                          SizedBox(height: BleyaTheme.spacingMD),
                          Text(
                            "Enter the code we just sent to ${widget.phoneNumber.startsWith('+') ? widget.phoneNumber : '+${widget.phoneNumber}'}",
                            style: BleyaTheme.bodyLarge,
                          ),
                          SizedBox(
                            height:
                                BleyaTheme.spacing3XL + BleyaTheme.spacing2XL,
                          ),

                          // 6-Digit Code Inputs
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: BleyaTheme.spacingSM,
                                ),
                                child: SizedBox(
                                  width: BleyaTheme.iconContainerSize,
                                  height: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _hasValue[index]
                                          ? BleyaTheme.primary
                                              .withValues(alpha: 0.05)
                                          : BleyaTheme.glassSurface.withValues(
                                              alpha: BleyaTheme.glassOpacity),
                                      borderRadius: BorderRadius.circular(
                                          BleyaTheme.radiusMedium),
                                      border: Border.all(
                                        color: _hasValue[index]
                                            ? BleyaTheme.primary
                                            : BleyaTheme.border,
                                        width: 1,
                                      ),
                                      boxShadow: _hasValue[index]
                                          ? [
                                              BoxShadow(
                                                color: BleyaTheme.primary
                                                    .withValues(alpha: 0.1),
                                                blurRadius: 3,
                                                offset: Offset(0, 0),
                                              ),
                                            ]
                                          : BleyaTheme.glassShadow,
                                    ),
                                    child: GestureDetector(
                                      // Prevent manual field selection - only allow keyboard input
                                      onTap: () {
                                        // Find the first empty field or last filled field
                                        int targetIndex = index;
                                        for (int i = 0; i < 6; i++) {
                                          if (!_hasValue[i]) {
                                            targetIndex = i;
                                            break;
                                          }
                                        }
                                        _focusNodes[targetIndex].requestFocus();
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            BleyaTheme.radiusMedium),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 20, sigmaY: 20),
                                          child: CupertinoTextField(
                                            controller: _codeControllers[index],
                                            focusNode: _focusNodes[index],
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            maxLength: 1,
                                            enableInteractiveSelection: false,
                                            showCursor: true,
                                            autofillHints: index == 0
                                                ? const [
                                                    AutofillHints.oneTimeCode
                                                  ]
                                                : null,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            padding: EdgeInsets.only(
                                              top: BleyaTheme.spacingLG,
                                              left: BleyaTheme.spacingXS,
                                              bottom: BleyaTheme.spacingSM,
                                            ),
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: _hasValue[index]
                                                  ? BleyaTheme.primary
                                                  : BleyaTheme.foreground,
                                            ),
                                            decoration: BoxDecoration(
                                                color: Colors.transparent),
                                            onChanged: (value) =>
                                                _handleCodeChange(index, value),
                                            onSubmitted: (_) {
                                              if (index < 5) {
                                                _focusNodes[index + 1]
                                                    .requestFocus();
                                              } else {
                                                _verifyCode();
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),

                          if (authState.errorMessage != null) ...[
                            SizedBox(height: BleyaTheme.spacing2XL),
                            Center(
                              child: Text(
                                authState.errorMessage!,
                                style: BleyaTheme.bodySmall.copyWith(
                                  color: BleyaTheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
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
                          text: 'Confirm',
                          onPressed: _verifyCode,
                          isLoading: authState.isLoading,
                          isEnabled: _isCodeComplete(),
                        ),
                        SizedBox(height: BleyaTheme.spacingLG),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _resendRemainingSeconds > 0 || _isResending
                              ? null
                              : _handleResend,
                          child: Text(
                            _resendRemainingSeconds > 0
                                ? "Resend code in ${_formatTime(_resendRemainingSeconds)}"
                                : "Didn't get it? Resend",
                            style: TextStyle(
                              color: _resendRemainingSeconds > 0 || _isResending
                                  ? BleyaTheme.mutedForeground
                                  : BleyaTheme.primary,
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
            ),
          ],
        ),
      ),
    );
  }
}
