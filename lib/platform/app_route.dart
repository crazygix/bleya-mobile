import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'ui_platform.dart';

class AppRoute {
  static Route<T> build<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    BuildContext? context,
  }) {
    if (isIosPlatform(context)) {
      return CupertinoPageRoute<T>(
        builder: builder,
        settings: settings,
        fullscreenDialog: fullscreenDialog,
      );
    }

    return MaterialPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }
}
