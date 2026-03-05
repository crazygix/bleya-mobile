import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'ui_platform.dart';

class AppIcon {
  static IconData adaptive({
    required IconData ios,
    required IconData android,
    BuildContext? context,
  }) {
    return isIosPlatform(context) ? ios : android;
  }

  static IconData back([BuildContext? context]) => adaptive(
        ios: CupertinoIcons.chevron_left,
        android: Icons.arrow_back,
        context: context,
      );

  static IconData chevronRight([BuildContext? context]) => adaptive(
        ios: CupertinoIcons.chevron_right,
        android: Icons.chevron_right,
        context: context,
      );

  static IconData more([BuildContext? context]) => adaptive(
        ios: CupertinoIcons.ellipsis_circle,
        android: Icons.more_horiz,
        context: context,
      );

  static IconData success([BuildContext? context]) => adaptive(
        ios: CupertinoIcons.check_mark_circled,
        android: Icons.check_circle_outline,
        context: context,
      );

  static IconData error([BuildContext? context]) => adaptive(
        ios: CupertinoIcons.exclamationmark_circle,
        android: Icons.error_outline,
        context: context,
      );

  static IconData info([BuildContext? context]) => adaptive(
        ios: CupertinoIcons.info_circle,
        android: Icons.info_outline,
        context: context,
      );
}
