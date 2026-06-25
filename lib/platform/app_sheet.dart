import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/theme.dart';
import 'ui_platform.dart';

class AppSheetAction<T> {
  final T value;
  final String label;
  final bool isDestructive;

  const AppSheetAction({
    required this.value,
    required this.label,
    this.isDestructive = false,
  });
}

class AppSheet {
  static Future<T?> actions<T>({
    required BuildContext context,
    required List<AppSheetAction<T>> actions,
    String cancelText = 'Cancel',
    String? title,
    String? message,
  }) {
    if (isIosPlatform(context)) {
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (context) => CupertinoTheme(
          // Drive non-destructive action text from the brand color instead of
          // iOS system blue, so sheets match the rest of the app.
          data: CupertinoTheme.of(context)
              .copyWith(primaryColor: BleyaTheme.primary),
          child: CupertinoActionSheet(
            title: title != null
                ? Text(
                    title,
                    style: const TextStyle(
                      color: BleyaTheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
            message: message != null
                ? Text(
                    message,
                    style: const TextStyle(color: BleyaTheme.mutedForeground),
                  )
                : null,
            actions: [
              for (final action in actions)
                CupertinoActionSheetAction(
                  isDestructiveAction: action.isDestructive,
                  onPressed: () => Navigator.of(context).pop(action.value),
                  child: Text(action.label),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText),
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  children: [
                    if (title != null)
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: BleyaTheme.foreground,
                        ),
                      ),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          message,
                          style: const TextStyle(
                            fontSize: 14,
                            color: BleyaTheme.mutedForeground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            for (final action in actions)
              ListTile(
                title: Text(
                  action.label,
                  style: TextStyle(
                    color: action.isDestructive
                        ? BleyaTheme.error
                        : BleyaTheme.foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(action.value),
              ),
            const Divider(height: 1),
            ListTile(
              title: Text(
                cancelText,
                style: const TextStyle(color: BleyaTheme.mutedForeground),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
