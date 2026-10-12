import 'package:flutter/widgets.dart';

/// Makes [child] tappable with the brand's press feedback, the "squish":
/// while a finger rests on it, it shrinks a little and dims, and on release
/// it springs back. A quick tap still shows the whole press, so every tap
/// visibly lands.
///
/// The press shows once the touch is a tap rather than the start of a
/// scroll (after Flutter's usual short delay), so rows in a list don't flash
/// while scrolling. Without [onTap] the child shows no feedback and isn't a
/// button.
///
/// Cards and buttons use the default squish. A full-width row, such as an
/// Activity item, passes `pressedScale: 1` to only dim.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.pressedOpacity = 0.75,
    this.behavior = HitTestBehavior.opaque,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  /// The size while pressed, as a share of the normal size.
  final double pressedScale;

  /// The opacity while pressed.
  final double pressedOpacity;

  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  static const _pressDuration = Duration(milliseconds: 90);
  static const _releaseDuration = Duration(milliseconds: 180);

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: _pressDuration,
    reverseDuration: _releaseDuration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeOut,
  );
  bool _isHeldDown = false;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _isHeldDown = true;
    _press.forward();
  }

  void _onTapUp(TapUpDetails details) => _release();

  void _onTapCancel() => _release();

  /// Springs back; a press too short to show finishes showing first.
  void _release() {
    _isHeldDown = false;
    if (_press.isCompleted || _press.status == AnimationStatus.reverse) {
      _press.reverse();
      return;
    }
    _press.forward().whenCompleteOrCancel(() {
      if (mounted && !_isHeldDown) _press.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: enabled ? _onTapDown : null,
        onTapUp: enabled ? _onTapUp : null,
        onTapCancel: enabled ? _onTapCancel : null,
        child: AnimatedBuilder(
          animation: _curve,
          child: widget.child,
          // The same widgets pressed or not, so the child is never rebuilt
          // from scratch; at rest both are free.
          builder: (context, child) {
            final t = _curve.value;
            return Opacity(
              opacity: 1 - (1 - widget.pressedOpacity) * t,
              child: Transform.scale(
                scale: animate ? 1 - (1 - widget.pressedScale) * t : 1,
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}
