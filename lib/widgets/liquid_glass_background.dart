import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Liquid Glass Background Component
///
/// The "Café Coast" background: three large, soft orbs of colour behind the
/// page, following the Bleya Design System's "Liquid Glass" visual language.
///
/// - Top right: primary (Coat Blue)
/// - Bottom left: secondary (Aqua Tint)
/// - Centre right: accent (Soft Sand)
///
/// Each orb is a radial gradient shaped like a strongly blurred disc. It is
/// painted once and cached, so it costs nothing while the page scrolls or
/// animates. It fills its parent; pages put it first in a Stack.
class LiquidGlassBackground extends StatelessWidget {
  const LiquidGlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: RepaintBoundary(
        child: CustomPaint(painter: _OrbsPainter()),
      ),
    );
  }
}

/// One orb: a disc of [color] blurred into a glow that fades out at [radius].
class _Orb {
  const _Orb({
    required this.color,
    required this.center,
    required this.radius,
    required this.peakAlpha,
    required this.falloff,
  });

  final Color color;

  /// Where the glow is centred, for a background of the given size.
  final Offset Function(Size size) center;

  /// Where the glow has faded out completely.
  final double radius;

  /// The opacity at the centre.
  final double peakAlpha;

  /// The opacity at [_stops], as a share of [peakAlpha].
  final List<double> falloff;
}

/// Gradient stops, as fractions of an orb's radius.
const _stops = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 1.0];

// How a disc fades once blurred, sampled at [_stops]. The blue and aqua orbs
// are blurred about as much relative to their size, so they share a curve;
// the sand one is sharper.
const _wideFalloff = [1.0, .943, .789, .583, .377, .212, .103, .043, .015, 0.0];
const _sandFalloff = [1.0, .962, .850, .674, .466, .274, .134, .054, .017, 0.0];

/// The orbs in painting order. Each looks like the strongly blurred disc the
/// background used to draw (500, 400 and 450 pt across, at alpha 0.06, 0.05
/// and 0.08), in the same place and colour.
final _orbs = [
  _Orb(
    color: BleyaTheme.primary,
    center: (size) => Offset(size.width - 190, 170),
    radius: 823,
    peakAlpha: .0345,
    falloff: _wideFalloff,
  ),
  _Orb(
    color: BleyaTheme.secondary,
    center: (size) => Offset(140, size.height - 160),
    radius: 646,
    peakAlpha: .0298,
    falloff: _wideFalloff,
  ),
  _Orb(
    color: BleyaTheme.accent,
    center: (size) => Offset(size.width - 145, 425),
    radius: 555,
    peakAlpha: .0701,
    falloff: _sandFalloff,
  ),
];

class _OrbsPainter extends CustomPainter {
  const _OrbsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    for (final orb in _orbs) {
      final center = orb.center(size);
      final gradient = RadialGradient(
        colors: [
          for (final share in orb.falloff)
            orb.color.withValues(alpha: orb.peakAlpha * share),
        ],
        stops: _stops,
      );
      final bounds = Rect.fromCircle(center: center, radius: orb.radius);
      canvas.drawCircle(
        center,
        orb.radius,
        Paint()..shader = gradient.createShader(bounds),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbsPainter oldDelegate) => false;
}
