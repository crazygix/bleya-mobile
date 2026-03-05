import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum UiPlatform { ios, android }

UiPlatform currentUiPlatform([BuildContext? context]) {
  final targetPlatform =
      context != null ? Theme.of(context).platform : defaultTargetPlatform;

  switch (targetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return UiPlatform.ios;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return UiPlatform.android;
  }
}

bool isIosPlatform([BuildContext? context]) =>
    currentUiPlatform(context) == UiPlatform.ios;

bool isAndroidPlatform([BuildContext? context]) =>
    currentUiPlatform(context) == UiPlatform.android;
