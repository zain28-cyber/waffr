// Soft moving color glow behind the smart analysis, brighter while it is
// "thinking" and calmer once the text is written.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// The four glow hues: the app accent, then greens and teals that cool
/// toward a soft blue. Kept mostly green so the smart features carry the
/// app's own identity.
List<Color> smartGlowColors(BuildContext context) {
  final accent = AppPalette.of(context).accent;
  return [
    accent,
    const Color(0xFF4CB782),
    const Color(0xFF3FB6A8),
    const Color(0xFF5E9FD6),
  ];
}

/// Any icon painted in the smart colors, for smart features that keep their
/// own glyph (alerts, auto category).
class SmartGradientIcon extends StatelessWidget {
  /// The icon.
  final IconData icon;

  /// Icon size.
  final double size;

  /// Creates a [SmartGradientIcon].
  const SmartGradientIcon(this.icon, {super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final colors = smartGlowColors(context);
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors[0], colors[1], colors[2]],
      ).createShader(bounds),
      child: Icon(icon, size: size),
    );
  }
}

/// The moving color glow behind the smart analysis.
class SmartGlowBackground extends StatefulWidget {
  /// 0 hides the glow, 1 is the full "generating" strength.
  final double intensity;

  /// Creates a [SmartGlowBackground].
  const SmartGlowBackground({super.key, required this.intensity});

  @override
  State<SmartGlowBackground> createState() => _SmartGlowBackgroundState();
}

/// State of [SmartGlowBackground].
class _SmartGlowBackgroundState extends State<SmartGlowBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDrift();
  }

  @override
  void didUpdateWidget(covariant SmartGlowBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDrift();
  }

  // The glow drifts only at full strength ("thinking"). The calm resting
  // glow stays still, so a finished report lets the screen stop drawing.
  void _syncDrift() {
    if (!AppMotion.enabled(context) || widget.intensity < 0.99) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = smartGlowColors(context);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.intensity),
        duration: AppMotion.of(context, const Duration(milliseconds: 900)),
        curve: AppMotion.standard,
        builder: (context, intensity, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _GlowPainter(
              drift: _drift,
              intensity: intensity,
              colors: colors,
              strength: isDark ? 0.42 : 0.30,
            ),
          );
        },
      ),
    );
  }
}

/// Paints the drifting color blobs of the glow.
class _GlowPainter extends CustomPainter {
  final Animation<double> drift;
  final double intensity;
  final List<Color> colors;
  final double strength;

  _GlowPainter({
    required this.drift,
    required this.intensity,
    required this.colors,
    required this.strength,
  }) : super(repaint: drift);

  // Anchor (fraction of size), drift radius and phase per blob. Two hug
  // the top edge and two the bottom, like light leaking around a screen.
  static const List<(Offset, double, double)> _blobs = [
    (Offset(0.15, 0.02), 0.10, 0.0),
    (Offset(0.85, 0.08), 0.12, 1.7),
    (Offset(0.25, 0.98), 0.12, 3.1),
    (Offset(0.80, 0.92), 0.10, 4.4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0.01) return;
    final t = drift.value * 2 * math.pi;
    final radius = size.shortestSide * 0.85;
    for (var i = 0; i < _blobs.length; i++) {
      final (anchor, wander, phase) = _blobs[i];
      final center = Offset(
        size.width * (anchor.dx + wander * math.sin(t + phase)),
        size.height * (anchor.dy + wander * 0.6 * math.cos(t * 0.8 + phase)),
      );
      final pulse = 0.85 + 0.15 * math.sin(t * 2 + phase);
      final color = colors[i % colors.length];
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: strength * intensity * pulse),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.intensity != intensity ||
      old.strength != strength ||
      !listEquals(old.colors, colors);
}

/// A sparkle inside a rotating color ring, the "thinking" mark.
class SmartSpark extends StatefulWidget {
  /// Width and height.
  final double size;

  /// Spins the ring while true.
  final bool spinning;

  /// Creates a [SmartSpark].
  const SmartSpark({super.key, this.size = 28, this.spinning = false});

  @override
  State<SmartSpark> createState() => _SmartSparkState();
}

/// State of [SmartSpark].
class _SmartSparkState extends State<SmartSpark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _settling = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SmartSpark oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (!AppMotion.enabled(context)) {
      _spin.stop();
      _settling = false;
      if (AppMotion.reduced(context)) _spin.value = 0;
      return;
    }
    final run = widget.spinning;
    if (run && (_settling || !_spin.isAnimating)) {
      _settling = false;
      _spin.repeat();
    } else if (!run && _spin.isAnimating) {
      // No delayed reset: it could reset a newly restarted spin or a
      // disposed controller. One full turn has the same resting pose as 0.
      if (!_settling) {
        _settling = true;
        _spin.animateTo(1, duration: AppMotion.medium);
      }
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = smartGlowColors(context);
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, child) {
          return CustomPaint(
            painter: _RingPainter(
              rotation: _spin.value * 2 * math.pi,
              colors: colors,
              visible: widget.spinning,
            ),
            child: child,
          );
        },
        child: Center(
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) =>
                LinearGradient(colors: [colors[0], colors[1], colors[2]])
                    .createShader(bounds),
            child: SizedBox.square(
              dimension: widget.size * 0.7,
              child: Stack(
                children: [
                  // A small rising chart line under the sparkle: analysis
                  // of the user's money, not just "magic".
                  const Positioned.fill(
                    child: CustomPaint(painter: _TrendLinePainter()),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Icon(Icons.auto_awesome, size: widget.size * 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three-segment trend line, painted white so the ShaderMask colors it.
class _TrendLinePainter extends CustomPainter {
  const _TrendLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.06, h * 0.92)
      ..lineTo(w * 0.27, h * 0.7)
      ..lineTo(w * 0.42, h * 0.81)
      ..lineTo(w * 0.6, h * 0.62);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TrendLinePainter oldDelegate) => false;
}

/// The color ring around the spark.
class _RingPainter extends CustomPainter {
  final double rotation;
  final List<Color> colors;
  final bool visible;

  _RingPainter({
    required this.rotation,
    required this.colors,
    required this.visible,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [...colors, colors.first],
        transform: GradientRotation(rotation),
      ).createShader(rect);
    canvas.drawArc(
      rect.deflate(size.width * 0.04),
      0,
      2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.rotation != rotation ||
      old.visible != visible ||
      !listEquals(old.colors, colors);
}
