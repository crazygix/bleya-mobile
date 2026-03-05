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
        _showAndroidToast(context, message, variant, duration);
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

  static void _showAndroidToast(
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
      builder: (_) => _AndroidToastBanner(
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

class _AndroidToastBanner extends StatelessWidget {
  final String message;
  final AppToastVariant variant;
  final ValueListenable<bool> isVisibleListenable;

  const _AndroidToastBanner({
    required this.message,
    required this.variant,
    required this.isVisibleListenable,
  });

  @override
  Widget build(BuildContext context) {
    final style = _AndroidToastStyle.fromVariant(variant);

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
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: style.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: style.border, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x29000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(style.icon, size: 18, color: style.iconColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: BleyaTheme.bodyMedium.copyWith(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w500,
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
    );
  }
}

class _AndroidToastStyle {
  final Color background;
  final Color border;
  final Color iconColor;
  final IconData icon;

  const _AndroidToastStyle({
    required this.background,
    required this.border,
    required this.iconColor,
    required this.icon,
  });

  factory _AndroidToastStyle.fromVariant(AppToastVariant variant) {
    switch (variant) {
      case AppToastVariant.success:
        return const _AndroidToastStyle(
          background: Color(0xFFE8F7EF),
          border: Color(0xFFB8E6CA),
          iconColor: Color(0xFF1B8D57),
          icon: Icons.check_circle_outline,
        );
      case AppToastVariant.error:
        return const _AndroidToastStyle(
          background: Color(0xFFFFEBEE),
          border: Color(0xFFFFCDD2),
          iconColor: Color(0xFFD32F2F),
          icon: Icons.error_outline,
        );
      case AppToastVariant.info:
        return const _AndroidToastStyle(
          background: Color(0xFFE3F2FD),
          border: Color(0xFFBBDEFB),
          iconColor: Color(0xFF1565C0),
          icon: Icons.info_outline,
        );
    }
  }
}
