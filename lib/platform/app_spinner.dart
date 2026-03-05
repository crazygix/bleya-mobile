import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'ui_platform.dart';

class PlatformAppSpinner extends StatelessWidget {
  final double size;
  final double? radius;
  final Color? color;

  const PlatformAppSpinner({
    super.key,
    this.size = 20,
    this.radius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = radius ?? size / 2;
    final dimension = radius != null ? radius! * 2 : size;
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;

    if (isIosPlatform(context)) {
      return SizedBox(
        width: dimension,
        height: dimension,
        child: CupertinoActivityIndicator(
          radius: effectiveRadius,
          color: resolvedColor,
        ),
      );
    }

    return SizedBox(
      width: dimension,
      height: dimension,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        color: resolvedColor,
      ),
    );
  }
}
