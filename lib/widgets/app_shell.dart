import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/theme.dart';
import '../providers/connectivity_provider.dart';

/// Wraps every screen of the app (from `MaterialApp.builder`).
///
/// - One status bar style for the whole app, [BleyaTheme.systemOverlayStyle].
///   A page can still set its own with an AnnotatedRegion.
/// - Tapping outside a text field closes the keyboard.
/// - While offline, a strip says so below the status bar and the app moves
///   down under it, so headers and back buttons stay visible.
///
/// The widget tree is the same online and offline, so open screens keep
/// their state when the connection comes and goes.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BleyaTheme.systemOverlayStyle,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OfflineStrip(visible: !isOnline),
            Expanded(
              // While the strip shows, it covers the status bar area, so the
              // screens below it get no top inset of their own.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: !isOnline,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip({required this.visible});

  final bool visible;

  /// Light status bar icons over the red strip.
  static final SystemUiOverlayStyle _overlayStyle =
      BleyaTheme.systemOverlayStyle.copyWith(
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: BleyaTheme.error,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BleyaTheme.contentPadding,
                vertical: BleyaTheme.spacingSM,
              ),
              child: Text(
                'No internet connection',
                textAlign: TextAlign.center,
                style: BleyaTheme.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
