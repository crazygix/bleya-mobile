import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
        builder: (context) => CupertinoActionSheet(
          title: title != null ? Text(title) : null,
          message: message != null ? Text(message) : null,
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  children: [
                    if (title != null)
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          message,
                          style: Theme.of(context).textTheme.bodyMedium,
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
                  style: action.isDestructive
                      ? const TextStyle(color: Colors.red)
                      : null,
                ),
                onTap: () => Navigator.of(context).pop(action.value),
              ),
            const Divider(height: 1),
            ListTile(
              title: Text(cancelText),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
