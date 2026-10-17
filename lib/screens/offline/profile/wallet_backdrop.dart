// The Waffr wallet drawn large and faint behind the profile's lower cards.
// The wallet is the logo artwork with its mouth removed; the mouth is a
// vector path redrawn on top, so only the smile changes with the health
// score and it morphs between poses instead of swapping images. While the
// tab is on screen the wallet breathes slowly.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Fills its box and hangs the wallet from the box's bottom edge. Fades in
/// once the artwork is cached and a [band] is known.
class WalletBackdrop extends StatefulWidget {
  /// The visible page; the wallet is sized from it.
  final Size page;

  /// Drives the smile. Null keeps the wallet hidden until the first read.
  final HealthBand? band;

  /// False while another tab is showing, so the idle motion stops.
  final bool active;

  /// Creates a [WalletBackdrop].
  const WalletBackdrop({
    super.key,
    required this.page,
    required this.band,
    required this.active,
  });

  /// The green strokes of waffr_logo.png (no mouth, no cream fill), blurred
  /// (sigma 6 at 1440 px) and faded out over the top 40%. The cream is left
  /// out so the wallet's body takes the page color in both themes.
  static const _asset = AssetImage('assets/brand/waffr_logo_backdrop.png');

  /// Blur of the artwork as a share of its size, matched by the mouth.
  static const double _blur = 6 / 1440;

  /// Share of the mark that hangs below the bottom of the page.
  static const double _sink = 0.08;

  /// Bigger than the page is wide, and scaled with the height so the smile
  /// lands in the free space under the cards on short and tall phones alike.
  static double _sizeFor(Size page) => math.min(
    math.max(page.height * 0.82, page.width * 1.35),
    math.min(page.width * 1.8, page.height * 1.2),
  );

  /// Bottom space the content should keep so the widest smile shows below
  /// its last card.
  static double contentClearance(Size page) {
    final size = _sizeFor(page);
    return size * (1 - _MouthShape.excellent.cornerY - _sink) + 20;
  }

  @override
  State<WalletBackdrop> createState() => _WalletBackdropState();
}

/// State of [WalletBackdrop]. Owns the fade-in and breathing controllers
/// and precaches the artwork once.
class _WalletBackdropState extends State<WalletBackdrop>
    with TickerProviderStateMixin {
  /// The logo's own green. Dark pages use the dark accent instead.
  static const Color _ink = Color(0xFF135239);

  /// Fade-in when the wallet first becomes visible.
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// Eased fade-in, mapped to the artwork and mouth opacity.
  late final CurvedAnimation _shown = CurvedAnimation(
    parent: _appear,
    curve: AppMotion.enter,
  );

  /// One slow inhale and exhale.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  /// The artwork finished precaching.
  bool _imageReady = false;

  /// Precache was started (it runs once).
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      precacheImage(WalletBackdrop._asset, context).then((_) {
        if (!mounted) return;
        setState(() => _imageReady = true);
        _sync();
      });
    }
    _sync();
  }

  @override
  void didUpdateWidget(covariant WalletBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Shown only once the artwork is ready and a band is known.
  bool get _visible => _imageReady && widget.band != null;

  /// Starts or stops the fade-in and breathing to match visibility, the
  /// active tab and the motion settings.
  void _sync() {
    if (!mounted) return;
    final reduced = AppMotion.reduced(context);
    if (!_visible) {
      _breath.stop();
      return;
    }

    if (reduced) {
      _appear.value = 1;
    } else if (_appear.isDismissed) {
      _appear.forward();
    }

    if (widget.active && AppMotion.enabled(context)) {
      if (!_breath.isAnimating) _breath.repeat();
    } else {
      _breath.stop();
      if (reduced) _breath.value = 0;
    }
  }

  @override
  void dispose() {
    _shown.dispose();
    _appear.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final band = widget.band;
    if (!_visible || band == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.of(context).accent : _ink;
    final opacity = _shown.drive(
      Tween<double>(begin: 0, end: isDark ? 0.12 : 0.14),
    );
    final size = WalletBackdrop._sizeFor(widget.page);

    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final box = constraints.biggest;
            // Artwork plus the morphing mouth, isolated from the breathing transform.
            final mark = RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: WalletBackdrop._asset,
                    fit: BoxFit.fill,
                    color: ink,
                    colorBlendMode: BlendMode.srcIn,
                    opacity: opacity,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                  TweenAnimationBuilder<_MouthShape>(
                    tween: _MouthTween(end: _MouthShape.of(band)),
                    duration: AppMotion.of(
                      context,
                      const Duration(milliseconds: 900),
                    ),
                    curve: AppMotion.standard,
                    builder: (context, mouth, _) => CustomPaint(
                      painter: _MouthPainter(
                        shape: mouth,
                        opacity: opacity,
                        color: ink,
                        blur: WalletBackdrop._blur,
                      ),
                    ),
                  ),
                ],
              ),
            );

            // The smile is centered; the clasp runs off the right edge.
            // Positions are absolute, so the mark is not mirrored in RTL.
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: box.width / 2 - _MouthShape.centerX * size,
                  top: box.height - size * (1 - WalletBackdrop._sink),
                  width: size,
                  height: size,
                  child: AnimatedBuilder(
                    animation: _breath,
                    child: mark,
                    builder: (context, child) {
                      // 0 at rest, 1 at the top of the breath.
                      final t = (1 - math.cos(_breath.value * 2 * math.pi)) / 2;
                      return Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.translationValues(0, -3 * t, 0)
                          ..scaleByDouble(1 + 0.012 * t, 1 + 0.012 * t, 1, 1),
                        child: child,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One pose of the mouth, in shares of the mark's size. Both lips are cubic
/// curves between the two corners; depths are how far their control points
/// sit below the corners (negative is above) and pulls how far those points
/// sit in from the corners, as a share of the half width.
@immutable
class _MouthShape {
  final double halfWidth;
  final double cornerY;
  final double upperDepth;
  final double lowerDepth;
  final double upperPull;
  final double lowerPull;

  const _MouthShape({
    required this.halfWidth,
    required this.cornerY,
    required this.upperDepth,
    required this.lowerDepth,
    required this.upperPull,
    required this.lowerPull,
  });

  /// Horizontal middle of the mouth in the artwork.
  static const double centerX = 651.5 / 1440;

  /// Traced from waffr_logo.png: the logo's own smile.
  static const excellent = _MouthShape(
    halfWidth: 301.5 / 1440,
    cornerY: 806.5 / 1440,
    upperDepth: 218 / 1440,
    lowerDepth: 343 / 1440,
    upperPull: 0.49,
    lowerPull: 0.2,
  );

  /// A smaller, softer smile around the same middle.
  static const good = _MouthShape(
    halfWidth: 262 / 1440,
    cornerY: 843 / 1440,
    upperDepth: 150 / 1440,
    lowerDepth: 245 / 1440,
    upperPull: 0.49,
    lowerPull: 0.2,
  );

  /// Close to a straight line.
  static const fair = _MouthShape(
    halfWidth: 222 / 1440,
    cornerY: 917 / 1440,
    upperDepth: -8 / 1440,
    lowerDepth: 56 / 1440,
    upperPull: 0.36,
    lowerPull: 0.36,
  );

  /// Corners turned slightly down.
  static const low = _MouthShape(
    halfWidth: 212 / 1440,
    cornerY: 974 / 1440,
    upperDepth: -104 / 1440,
    lowerDepth: -44 / 1440,
    upperPull: 0.2,
    lowerPull: 0.49,
  );

  /// The pose for a health band.
  static _MouthShape of(HealthBand band) => switch (band) {
    HealthBand.excellent => excellent,
    HealthBand.good => good,
    HealthBand.fair => fair,
    HealthBand.low => low,
  };

  /// Linear blend toward [other] at [t].
  _MouthShape lerpTo(_MouthShape other, double t) {
    double mix(double a, double b) => a + (b - a) * t;
    return _MouthShape(
      halfWidth: mix(halfWidth, other.halfWidth),
      cornerY: mix(cornerY, other.cornerY),
      upperDepth: mix(upperDepth, other.upperDepth),
      lowerDepth: mix(lowerDepth, other.lowerDepth),
      upperPull: mix(upperPull, other.upperPull),
      lowerPull: mix(lowerPull, other.lowerPull),
    );
  }

  /// Closed path of both lips for a mark [size] pixels wide.
  Path toPath(double size) {
    final left = (centerX - halfWidth) * size;
    final right = (centerX + halfWidth) * size;
    final y = cornerY * size;
    final half = halfWidth * size;
    final upperIn = upperPull * half;
    final lowerIn = lowerPull * half;
    final upperY = y + upperDepth * size;
    final lowerY = y + lowerDepth * size;

    return Path()
      ..moveTo(left, y)
      ..cubicTo(left + upperIn, upperY, right - upperIn, upperY, right, y)
      ..cubicTo(right - lowerIn, lowerY, left + lowerIn, lowerY, left, y)
      ..close();
  }
}

/// Tween that morphs between mouth poses.
class _MouthTween extends Tween<_MouthShape> {
  _MouthTween({super.end});

  @override
  _MouthShape lerp(double t) => begin!.lerpTo(end!, t);
}

/// Paints the mouth in [color] with the artwork's blur and fade.
class _MouthPainter extends CustomPainter {
  final _MouthShape shape;
  final Animation<double> opacity;
  final Color color;
  final double blur;

  _MouthPainter({
    required this.shape,
    required this.opacity,
    required this.color,
    required this.blur,
  }) : super(repaint: opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = opacity.value;
    if (alpha <= 0 || size.isEmpty) return;
    canvas.drawPath(
      shape.toPath(size.width),
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * size.width),
    );
  }

  @override
  bool shouldRepaint(covariant _MouthPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.opacity != opacity ||
      oldDelegate.color != color ||
      oldDelegate.blur != blur;
}
