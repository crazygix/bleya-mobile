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
  static const int _digitCount = 6;
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();

  DateTime? _codeSentAt;
  int _resendRemainingSeconds = 60;
  Timer? _countdownTimer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _codeFocusNode.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusCodeInput();
    });
    if (widget.codeSentAt != null) {
      _updateCodeSentTime(widget.codeSentAt);
    } else {
      _codeSentAt = DateTime.now();
      _resendRemainingSeconds = 60;
      _startCountdown();
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
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _focusCodeInput() {
    FocusScope.of(context).requestFocus(_codeFocusNode);
    final code = _codeController.text;
    _codeController.selection = TextSelection.collapsed(offset: code.length);
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  void _handleCodeChange(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final nextCode =
        digits.length > _digitCount ? digits.substring(0, _digitCount) : digits;

    if (nextCode != value) {
      _codeController.value = TextEditingValue(
        text: nextCode,
        selection: TextSelection.collapsed(offset: nextCode.length),
      );
      return;
    }

    setState(() {});
  }

  bool _isCellFilled(int index) {
    return index < _codeController.text.length;
  }

  bool _isCellActive(int index) {
    if (!_codeFocusNode.hasFocus) return false;
    final codeLength = _codeController.text.length;
    final activeIndex = codeLength < _digitCount ? codeLength : _digitCount - 1;
    return index == activeIndex;
  }

  String _digitForCell(int index) {
    if (!_isCellFilled(index)) return '';
    return _codeController.text[index];
  }

  String _getCode() {
    return _codeController.text;
  }

  bool _isCodeComplete() {
    return _codeController.text.length == _digitCount;
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
    final normalizedPhone = widget.phoneNumber.startsWith('+')
        ? widget.phoneNumber
        : '+${widget.phoneNumber}';
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
                            "Confirm it's you",
                            style: BleyaTheme.headingMedium,
                          ),
                          SizedBox(height: BleyaTheme.spacingMD),
                          RichText(
                            text: TextSpan(
                              style: BleyaTheme.bodyLarge,
                              children: [
                                TextSpan(
                                  text: 'Enter the code we just sent to ',
                                ),
                                TextSpan(
                                  text: normalizedPhone,
                                  style: BleyaTheme.bodyLarge.copyWith(
                                    color: BleyaTheme.foreground,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height:
                                BleyaTheme.spacing3XL + BleyaTheme.spacing2XL,
                          ),

                          // 6-Digit Code Inputs
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _focusCodeInput,
                            child: Column(
                              children: [
                                Opacity(
                                  opacity: 0,
                                  child: SizedBox(
                                    width: 1,
                                    height: 1,
                                    child: CupertinoTextField(
                                      controller: _codeController,
                                      focusNode: _codeFocusNode,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      maxLength: _digitCount,
                                      enableInteractiveSelection: false,
                                      autofillHints: const [
                                        AutofillHints.oneTimeCode,
                                      ],
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(
                                            _digitCount),
                                      ],
                                      style: TextStyle(
                                        color: Colors.transparent,
                                        fontSize: 1,
                                      ),
                                      cursorColor: Colors.transparent,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onChanged: _handleCodeChange,
                                      onSubmitted: (_) {
                                        if (_isCodeComplete()) {
                                          _verifyCode();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(height: BleyaTheme.spacingXS),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final gap = BleyaTheme.spacingXS;
                                    final cellWidth = (constraints.maxWidth -
                                            (gap * (_digitCount - 1))) /
                                        _digitCount;

                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children:
                                          List.generate(_digitCount, (index) {
                                        final isFilled = _isCellFilled(index);
                                        final isActive = _isCellActive(index);
                                        final showFrame = isFilled || isActive;
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            right: index == _digitCount - 1
                                                ? 0
                                                : gap,
                                          ),
                                          child: SizedBox(
                                            width: cellWidth,
                                            height: 60,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: BleyaTheme.glassSurface
                                                    .withValues(
                                                        alpha: BleyaTheme
                                                            .glassOpacity),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        BleyaTheme
                                                            .radiusMedium),
                                                border: Border.all(
                                                  color: showFrame
                                                      ? BleyaTheme.primary
                                                      : BleyaTheme.border,
                                                  width: 1,
                                                ),
                                                boxShadow:
                                                    BleyaTheme.glassShadow,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        BleyaTheme
                                                            .radiusMedium),
                                                child: BackdropFilter(
                                                  filter: ImageFilter.blur(
                                                      sigmaX: 20, sigmaY: 20),
                                                  child: Center(
                                                    child: Text(
                                                      _digitForCell(index),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 24,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: BleyaTheme
                                                            .foreground,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    );
                                  },
                                ),
                              ],
                            ),
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
