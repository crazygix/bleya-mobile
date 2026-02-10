import 'package:flutter/cupertino.dart';
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
    final effectiveRadius = radius ?? size / 2;
    final dimension = radius != null ? radius! * 2 : size;

    return SizedBox(
      width: dimension,
      height: dimension,
      child: CupertinoActivityIndicator(
        radius: effectiveRadius,
        color: color ?? BleyaTheme.primary,
      ),
    );
  }
}
