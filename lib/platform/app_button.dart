import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'ui_platform.dart';

enum AppButtonVariant { plain, filled }

class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? disabledColor;
  final Size? minimumSize;
  final AppButtonVariant variant;
  final BorderRadius? borderRadius;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.color,
    this.disabledColor,
    this.minimumSize,
    this.variant = AppButtonVariant.plain,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = variant == AppButtonVariant.filled;

    if (isIosPlatform(context)) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: padding,
        minimumSize: minimumSize ?? Size.zero,
        color: isFilled ? color : Colors.transparent,
        disabledColor: disabledColor ?? Colors.transparent,
        child: child,
      );
    }

    if (isFilled) {
      final style = FilledButton.styleFrom(
        padding: padding,
        minimumSize: minimumSize,
        shape: borderRadius != null
            ? RoundedRectangleBorder(borderRadius: borderRadius!)
            : null,
        backgroundColor: color,
        disabledBackgroundColor: disabledColor,
      );

      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: child,
      );
    }

    final style = TextButton.styleFrom(
      padding: padding,
      minimumSize: minimumSize,
      shape: borderRadius != null
          ? RoundedRectangleBorder(borderRadius: borderRadius!)
          : null,
    );

    return TextButton(
      onPressed: onPressed,
      style: style,
      child: child,
    );
  }
}
