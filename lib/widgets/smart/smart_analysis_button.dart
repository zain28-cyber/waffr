// The "smart analysis" entry point: a compact pill for card headers, a
// small square tile that sits inside a card, and a full-width banner. All
// open SmartAnalysisScreen.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/screens/offline/smart/smart_analysis_screen.dart';
import 'package:waffr/widgets/smart/smart_glow.dart';

/// How a [SmartAnalysisButton] is drawn.
enum SmartButtonStyle {
  /// A compact pill for card headers.
  pill,

  /// A small square tile inside a card.
  tile,

  /// A full-width banner.
  banner,
}

/// Opens the smart analysis for [scope].
class SmartAnalysisButton extends StatefulWidget {
  /// Which area the analysis looks at.
  final InsightScope scope;

  /// How the button is drawn.
  final SmartButtonStyle style;

  /// A roomier pill, for screens where it stands on its own.
  final bool large;

  /// Creates a [SmartAnalysisButton].
  const SmartAnalysisButton({
    super.key,
    required this.scope,
    this.style = SmartButtonStyle.pill,
    this.large = false,
  });

  @override
  State<SmartAnalysisButton> createState() => _SmartAnalysisButtonState();
}

/// State of [SmartAnalysisButton].
class _SmartAnalysisButtonState extends State<SmartAnalysisButton>
    with SingleTickerProviderStateMixin {
  // Set once the user has opened the analysis; shared by every button.
  static const String _seenKey = 'smart_analysis_seen';
  static final ValueNotifier<bool> _seen = ValueNotifier<bool>(
    AppPrefs.cached?.getBool(_seenKey) ?? false,
  );

  // Slow turn of the gradient border so the button reads as "alive" until
  // the user has opened the analysis once; after that the border rests.
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  @override
  void initState() {
    super.initState();
    _seen.addListener(_syncTurn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTurn();
  }

  bool _turned = false;

  void _syncTurn() {
    if (!mounted) return;
    if (_seen.value || !AppMotion.enabled(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating && !_turned) {
      // A couple of slow turns to draw the eye, then it rests; an endless
      // loop kept the app drawing frames on every tab that holds a button.
      _turned = true;
      _turn.repeat(count: 2);
    }
  }

  @override
  void dispose() {
    _seen.removeListener(_syncTurn);
    _turn.dispose();
    super.dispose();
  }

  void _open() {
    AppHaptics.selection();
    if (!_seen.value) {
      _seen.value = true;
      AppPrefs.instance.then((prefs) => prefs.setBool(_seenKey, true));
    }
    openSmartAnalysis(context, widget.scope);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final colors = smartGlowColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = widget.style;
    final radius = BorderRadius.circular(switch (style) {
      SmartButtonStyle.pill => 999,
      SmartButtonStyle.tile => 20,
      SmartButtonStyle.banner => 22,
    });

    // The spark flies into the analysis screen when it opens.
    final spark = Hero(
      tag: smartSparkHeroTag(widget.scope),
      child: SmartSpark(
        size: switch (style) {
          SmartButtonStyle.pill => widget.large ? 26 : 20,
          SmartButtonStyle.tile => 30,
          SmartButtonStyle.banner => 30,
        },
      ),
    );

    // Text and layout per style.
    final Widget content = switch (style) {
      SmartButtonStyle.banner => Row(
        children: [
          spark,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'التحليل الذكي',
                  style: _text(palette.textPrimary, 15, FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'اكتشف أين يذهب مالك واحصل على اقتراحات',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(palette.textSecondary, 12.5, FontWeight.w500),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: palette.textSecondary),
        ],
      ),
      SmartButtonStyle.tile => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          spark,
          const SizedBox(height: 6),
          // Wraps onto two centered lines when the tile is narrow.
          Text(
            'التحليل الذكي',
            maxLines: 2,
            textAlign: TextAlign.center,
            style: _text(
              palette.textPrimary,
              12,
              FontWeight.w800,
            ).copyWith(height: 1.15),
          ),
        ],
      ),
      SmartButtonStyle.pill => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          spark,
          SizedBox(width: widget.large ? 8 : 6),
          Text(
            'تحليل ذكي',
            style: _text(
              palette.textPrimary,
              widget.large ? 14.5 : 12.5,
              widget.large ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    };

    // A slowly turning gradient border around a softly tinted fill.
    return Semantics(
      button: true,
      label: 'التحليل الذكي',
      child: GestureDetector(
        onTap: _open,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _turn,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(1.6),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: SweepGradient(
                    colors: [...colors, colors.first],
                    transform: GradientRotation(_turn.value * 2 * math.pi),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors[2].withValues(alpha: 0.18),
                      blurRadius: style == SmartButtonStyle.pill ? 10 : 18,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Container(
              // The tile fills whatever box it is given, content centered.
              alignment: style == SmartButtonStyle.tile
                  ? Alignment.center
                  : null,
              padding: switch (style) {
                SmartButtonStyle.pill =>
                  widget.large
                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                      : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                SmartButtonStyle.tile => const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                SmartButtonStyle.banner => const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              },
              decoration: BoxDecoration(
                // A faint wash of the border colors over the surface.
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    for (final color in [colors[1], colors[3]])
                      Color.alphaBlend(
                        color.withValues(alpha: isDark ? 0.10 : 0.07),
                        palette.surface,
                      ),
                  ],
                ),
                borderRadius: radius,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  static TextStyle _text(Color color, double size, FontWeight weight) =>
      TextStyle(
        fontFamily: 'Outfit',
        fontFamilyFallback: const ['Tajawal'],
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
}
