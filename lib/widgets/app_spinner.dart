import 'package:flutter/cupertino.dart';

import '../platform/app_spinner.dart';
import '../constants/theme.dart';

/// Shared spinner used for action-level loading states.
class AppSpinner extends StatelessWidget {
  final double size;
  final double? radius;
  final Color? color;

  const AppSpinner({
    super.key,
    this.size = 20,
    this.radius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformAppSpinner(
      size: size,
      radius: radius,
      color: color ?? BleyaTheme.primary,
    );
  }
}
