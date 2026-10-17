// Full-screen moment shown once when the daily streak grows on app open.
//
// One controller drives the whole sequence: the screen behind blurs in, the
// Waffr logo rises into place, the day count rolls from the old value to the
// new one, holds, then everything fades and the blur clears. Tapping skips to
// the fade. When it ends the widget calls [onFinished] and is removed, so it
// never stays over the home screen.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/widgets/brand/waffr_logo.dart';

/// The streak celebration shown over the app on open.
class StreakCelebrationOverlay extends StatefulWidget {
  /// Streak before today.
  final int from;

  /// Streak after today counted.
  final int to;

  /// Called once when the sequence ends or is skipped.
  final VoidCallback onFinished;

  /// Creates a [StreakCelebrationOverlay].
  const StreakCelebrationOverlay({
    super.key,
    required this.from,
    required this.to,
    required this.onFinished,
  });

  @override
  State<StreakCelebrationOverlay> createState() =>
      _StreakCelebrationOverlayState();
}

/// State of [StreakCelebrationOverlay].
class _StreakCelebrationOverlayState extends State<StreakCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 3600);

  // Phases as fractions of [_total].
  static const double _fadeOutStart = 0.80;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  );

  // 1. Blur and tint come in first and leave last.
  late final CurvedAnimation _backdropIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.16, curve: AppMotion.enter),
  );
  late final CurvedAnimation _backdropOut = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.86, 1.0, curve: AppMotion.standard),
  );

  // 2. Logo rises and settles.
  late final CurvedAnimation _logoIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.08, 0.30, curve: AppMotion.overshoot),
  );
  late final CurvedAnimation _logoFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.08, 0.22, curve: AppMotion.soft),
  );

  // 3. The count rolls to the new value.
  late final CurvedAnimation _countIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.22, 0.34, curve: AppMotion.enter),
  );
  late final CurvedAnimation _roll = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.36, 0.56, curve: AppMotion.standard),
  );

  // 5. Content leaves before the blur does.
  late final CurvedAnimation _contentOut = CurvedAnimation(
    parent: _controller,
    curve: const Interval(_fadeOutStart, 0.94, curve: AppMotion.exit),
  );

  bool _ticked = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
      _finishOnce();
    } else if (!_finished && _controller.isDismissed) {
      _controller.forward();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finishOnce();
  }

  // Skip and natural completion share one callback. Defer parent updates
  // past this build, including a reduced-motion change during animation.
  void _finishOnce() {
    if (_finished) return;
    _finished = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.removeStatusListener(_onStatus);
    _backdropIn.dispose();
    _backdropOut.dispose();
    _logoIn.dispose();
    _logoFade.dispose();
    _countIn.dispose();
    _roll.dispose();
    _contentOut.dispose();
    _controller.dispose();
    super.dispose();
  }

  // A light tap of haptics as the new number lands.
  void _onTick() {
    if (_ticked || _roll.value < 0.98) return;
    _ticked = true;
    HapticFeedback.lightImpact();
  }

  void _skip() {
    if (_controller.value >= _fadeOutStart) return;
    _controller.value = _fadeOutStart;
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return const SizedBox.shrink();
    final palette = AppPalette.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final backdrop = _backdropIn.value * (1 - _backdropOut.value);
          final content = 1 - _contentOut.value;
          final sigma = 14 * backdrop;

          Widget layer = ColoredBox(
            color: palette.background.withValues(alpha: 0.38 * backdrop),
            child: const SizedBox.expand(),
          );
          if (sigma > 0.05) {
            layer = BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: layer,
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(child: layer),
              Center(
                child: Opacity(
                  opacity: content.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.96 + 0.04 * content,
                    child: _CelebrationContent(
                      from: widget.from,
                      to: widget.to,
                      logoIn: _logoIn.value,
                      logoFade: _logoFade.value,
                      countIn: _countIn.value,
                      roll: _roll.value,
                      palette: palette,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Logo, rolling count and caption, positioned by the sequence values.
class _CelebrationContent extends StatelessWidget {
  /// Number before the roll.
  final int from;

  /// Number after the roll.
  final int to;
  final double logoIn;
  final double logoFade;
  final double countIn;
  final double roll;
  final AppPalette palette;

  const _CelebrationContent({
    required this.from,
    required this.to,
    required this.logoIn,
    required this.logoFade,
    required this.countIn,
    required this.roll,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final glow = palette.accent.withValues(alpha: 0.22 * logoFade);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: logoFade.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - logoIn)),
            child: Transform.scale(
              scale: 0.7 + 0.3 * logoIn,
              child: Container(
                width: 132,
                height: 132,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glow, glow.withValues(alpha: 0)],
                  ),
                ),
                child: const WaffrLogo(size: 96),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: countIn.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - countIn)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RollingNumber(
                  from: from,
                  to: to,
                  progress: roll,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 64,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'أيام متواصلة',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Odometer-style number: each digit that changes rolls up from the old
/// value to the new one, with a slight tilt as it passes. [progress] is 0..1.
class RollingNumber extends StatelessWidget {
  /// Number before the roll.
  final int from;

  /// Number after the roll.
  final int to;

  /// Roll progress, 0..1.
  final double progress;

  /// Digit style.
  final TextStyle style;

  /// Creates a [RollingNumber].
  const RollingNumber({
    super.key,
    required this.from,
    required this.to,
    required this.progress,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final oldText = '$from';
    final newText = '$to';
    final width = math.max(oldText.length, newText.length);
    final oldDigits = oldText.padLeft(width);
    final newDigits = newText.padLeft(width);
    final painter = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final height = painter.height;
    final digitWidth = painter.width;
    painter.dispose();

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < width; i++)
            _RollingDigit(
              from: oldDigits[i],
              to: newDigits[i],
              progress: progress,
              style: style,
              height: height,
              width: digitWidth,
            ),
        ],
      ),
    );
  }
}

/// One digit column of [RollingNumber].
class _RollingDigit extends StatelessWidget {
  final String from;
  final String to;
  final double progress;
  final TextStyle style;
  final double height;
  final double width;

  const _RollingDigit({
    required this.from,
    required this.to,
    required this.progress,
    required this.style,
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    // A digit that only appears (9 -> 10) grows in from nothing.
    final appearing = from.trim().isEmpty;
    final slotWidth = appearing ? width * progress : width;

    if (from == to) {
      return SizedBox(
        width: slotWidth,
        height: height,
        child: Center(child: Text(to, style: style)),
      );
    }

    Widget face(String digit, double offset) {
      final tilt = offset.clamp(-1.0, 1.0) * 0.9;
      return Transform.translate(
        offset: Offset(0, offset * height),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(tilt),
          child: Opacity(
            opacity: (1 - offset.abs()).clamp(0.0, 1.0),
            child: Center(child: Text(digit, style: style)),
          ),
        ),
      );
    }

    return ClipRect(
      child: SizedBox(
        width: slotWidth,
        height: height,
        child: OverflowBox(
          maxWidth: width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!appearing) face(from, -progress),
              face(to, 1 - progress),
            ],
          ),
        ),
      ),
    );
  }
}
