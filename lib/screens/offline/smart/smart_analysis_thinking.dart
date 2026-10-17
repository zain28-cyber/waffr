// Smart analysis "thinking" pieces (part of smart_analysis_screen.dart):
// shimmer placeholders, typed text and the glowing caret at its end.

part of 'smart_analysis_screen.dart';

/// Placeholder layout shown while the analysis is thinking: a shimmer
/// headline block and three shimmer cards.
class _ThinkingView extends StatelessWidget {
  const _ThinkingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
      children: [
        const _Shimmer(widths: [1, 0.86, 0.62]),
        const SizedBox(height: 18),
        for (var i = 0; i < 3; i++) ...[
          GlassContainer(
            colorType: GlassColorType.surface,
            borderRadius: 22,
            padding: const EdgeInsets.all(16),
            child: _Shimmer(widths: [0.5, 1, 0.78 - i * 0.12]),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Placeholder lines with a moving highlight, in the glow colors.
class _Shimmer extends StatefulWidget {
  // Width of each line as a fraction of the available width.
  final List<double> widths;

  const _Shimmer({required this.widths});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

/// State of [_Shimmer]. Owns the repeating sweep controller, stopped when
/// motion is turned off.
class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.enabled(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final colors = smartGlowColors(context);
    final base = palette.textPrimary.withValues(alpha: 0.07);
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) {
        final shift = _sweep.value * 3 - 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final width in widget.widths)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: width,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment(shift - 1, 0),
                        end: Alignment(shift + 1, 0),
                        colors: [
                          base,
                          colors[2].withValues(alpha: 0.28),
                          colors[0].withValues(alpha: 0.22),
                          base,
                        ],
                        stops: const [0.0, 0.4, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Text that is still being written, with a glowing caret at its end.
class _TypedText extends StatelessWidget {
  final String text;
  final bool typing;
  final TextStyle style;

  const _TypedText({
    super.key,
    required this.text,
    required this.typing,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text),
          if (typing)
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _Caret(),
            ),
        ],
      ),
    );
  }
}

/// Small glowing gradient dot that marks the typing position.
class _Caret extends StatelessWidget {
  const _Caret();

  @override
  Widget build(BuildContext context) {
    final colors = smartGlowColors(context);
    return Container(
      width: 9,
      height: 9,
      margin: const EdgeInsetsDirectional.only(start: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [colors[0], colors[2]]),
        boxShadow: [
          BoxShadow(color: colors[2].withValues(alpha: 0.6), blurRadius: 8),
        ],
      ),
    );
  }
}
