import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/theme.dart';
import 'navigation.dart';

enum AppToastVariant { info, success, error }

class AppToast {
  static OverlayEntry? _activeToast;
  static Timer? _dismissTimer;
  static const Duration _defaultDuration = Duration(seconds: 3);

  static void show(
    BuildContext context, {
    required String message,
    AppToastVariant variant = AppToastVariant.info,
    Duration duration = _defaultDuration,
  }) {
    if (message.trim().isEmpty) return;

    final rootContext = navigatorKey.currentContext ?? context;
    final platform = Theme.of(rootContext).platform;

    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        _showIosToast(context, message, variant, duration);
        return;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        // Temporary: iOS look is used everywhere until Android visuals are defined.
        _showIosToast(context, message, variant, duration);
        return;
    }
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = _defaultDuration,
  }) {
    show(
      context,
      message: message,
      variant: AppToastVariant.success,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = _defaultDuration,
  }) {
    show(
      context,
      message: message,
      variant: AppToastVariant.error,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = _defaultDuration,
  }) {
    show(
      context,
      message: message,
      variant: AppToastVariant.info,
      duration: duration,
    );
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _activeToast?.remove();
    _activeToast = null;
  }

  static void _showIosToast(
    BuildContext context,
    String message,
    AppToastVariant variant,
    Duration duration,
  ) {
    final overlay = navigatorKey.currentState?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: duration,
          ),
        );
      }
      return;
    }

    dismiss();

    final entry = OverlayEntry(
      builder: (_) => _IosToastBanner(
        message: message,
        variant: variant,
      ),
    );

    _activeToast = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, dismiss);
  }
}

class _IosToastBanner extends StatelessWidget {
  final String message;
  final AppToastVariant variant;

  const _IosToastBanner({
    required this.message,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    final style = _IosToastStyle.fromVariant(variant);

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * -10),
                    child: child,
                  ),
                );
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      constraints: const BoxConstraints(minWidth: 120),
                      decoration: BoxDecoration(
                        color: _IosToastStyle.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _IosToastStyle.border,
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(style.icon,
                                color: style.iconColor, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              message,
                              softWrap: true,
                              style: BleyaTheme.bodyMedium.copyWith(
                                color: BleyaTheme.foreground87,
                                fontWeight: FontWeight.normal,
                                height: 1.25,
                                decoration: TextDecoration.none,
                                fontFamily: BleyaTheme.bodyMedium.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IosToastStyle {
  final Color iconColor;
  final IconData icon;

  const _IosToastStyle({
    required this.iconColor,
    required this.icon,
  });

  // Explicit ARGB values to avoid runtime color-conversion issues in static init.
  static const Color background = Color(0xF0D8E8FF);
  static const Color border = Color(0xE68FB2F2);

  factory _IosToastStyle.fromVariant(AppToastVariant variant) {
    switch (variant) {
      case AppToastVariant.success:
        return _IosToastStyle(
          iconColor: BleyaTheme.success,
          icon: CupertinoIcons.check_mark_circled,
        );
      case AppToastVariant.error:
        return _IosToastStyle(
          iconColor: BleyaTheme.error,
          icon: CupertinoIcons.exclamationmark_circle,
        );
      case AppToastVariant.info:
        return _IosToastStyle(
          iconColor: BleyaTheme.primary,
          icon: CupertinoIcons.info_circle,
        );
    }
  }
}
