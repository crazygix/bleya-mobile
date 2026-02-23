import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/theme.dart';
import 'navigation.dart';

enum AppToastVariant { info, success, error }

class AppToast {
  static OverlayEntry? _activeToast;
  static ValueNotifier<bool>? _visibilityNotifier;
  static Timer? _dismissTimer;
  static Timer? _removeTimer;
  static const Duration _defaultDuration = Duration(seconds: 3);
  static const Duration _transitionDuration = Duration(milliseconds: 220);

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

  static void dismiss({bool immediate = false}) {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    _removeTimer?.cancel();
    _removeTimer = null;

    final visibility = _visibilityNotifier;
    if (!immediate && visibility != null) {
      visibility.value = false;
      _removeTimer = Timer(_transitionDuration, _removeActiveToast);
      return;
    }

    _removeActiveToast();
  }

  static void _removeActiveToast() {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    _removeTimer?.cancel();
    _removeTimer = null;

    _activeToast?.remove();
    _activeToast = null;

    _visibilityNotifier?.dispose();
    _visibilityNotifier = null;
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

    dismiss(immediate: true);

    final visibilityNotifier = ValueNotifier<bool>(false);

    final entry = OverlayEntry(
      builder: (_) => _IosToastBanner(
        message: message,
        variant: variant,
        isVisibleListenable: visibilityNotifier,
      ),
    );

    _activeToast = entry;
    _visibilityNotifier = visibilityNotifier;
    overlay.insert(entry);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_visibilityNotifier == visibilityNotifier) {
        visibilityNotifier.value = true;
      }
    });

    _dismissTimer = Timer(duration, dismiss);
  }
}

class _IosToastBanner extends StatelessWidget {
  final String message;
  final AppToastVariant variant;
  final ValueListenable<bool> isVisibleListenable;

  const _IosToastBanner({
    required this.message,
    required this.variant,
    required this.isVisibleListenable,
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
            child: ValueListenableBuilder<bool>(
              valueListenable: isVisibleListenable,
              builder: (context, isVisible, child) {
                return AnimatedOpacity(
                  opacity: isVisible ? 1 : 0,
                  duration: AppToast._transitionDuration,
                  curve: isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
                  child: AnimatedSlide(
                    offset: isVisible ? Offset.zero : const Offset(0, -0.12),
                    duration: AppToast._transitionDuration,
                    curve: isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
                    child: child,
                  ),
                );
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      constraints: const BoxConstraints(minWidth: 120),
                      decoration: BoxDecoration(
                        color: _IosToastStyle.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _IosToastStyle.border, width: 0.9),
                        boxShadow: const [
                          BoxShadow(
                            color: _IosToastStyle.shadow,
                            blurRadius: 20,
                            offset: Offset(0, 10),
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
                              maxLines: 3,
                              style: BleyaTheme.bodyMedium.copyWith(
                                color: Colors.white,
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

  static const Color background = Color(0x96223552);
  static const Color border = Color(0x66FFFFFF);
  static const Color shadow = Color(0x2A0B1220);

  factory _IosToastStyle.fromVariant(AppToastVariant variant) {
    switch (variant) {
      case AppToastVariant.success:
        return _IosToastStyle(
          iconColor: const Color(0xFF6EE7B7),
          icon: CupertinoIcons.check_mark_circled,
        );
      case AppToastVariant.error:
        return _IosToastStyle(
          iconColor: const Color(0xFFFCA5A5),
          icon: CupertinoIcons.exclamationmark_circle,
        );
      case AppToastVariant.info:
        return _IosToastStyle(
          iconColor: const Color(0xFF93C5FD),
          icon: CupertinoIcons.info_circle,
        );
    }
  }
}
