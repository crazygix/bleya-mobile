import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Animated skeleton block for content loading placeholders.
class AppSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;

  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  const AppSkeleton.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = BoxShape.circle;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = BleyaTheme.primary.withValues(alpha: 0.08);
    final highlightColor = Colors.white.withValues(alpha: 0.78);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final sweep = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : (widget.borderRadius ??
                    BorderRadius.circular(BleyaTheme.radiusSmall)),
            border: Border.all(
              color: BleyaTheme.border.withValues(alpha: 0.45),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment(-1.6 + (3.2 * sweep), -0.2),
              end: Alignment(-0.6 + (3.2 * sweep), 0.2),
              colors: [
                baseColor,
                baseColor,
                highlightColor,
                baseColor,
                baseColor,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
          ),
        );
      },
    );
  }
}
