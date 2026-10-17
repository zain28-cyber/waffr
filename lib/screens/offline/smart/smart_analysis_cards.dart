// Smart analysis results (part of smart_analysis_screen.dart): one card per
// insight and the wallet health gauge.

part of 'smart_analysis_screen.dart';

/// One insight: tone-coloured icon, title and typed body. Once writing is
/// done, a tap expands the numbers behind it and its action button.
class _InsightCard extends StatelessWidget {
  final SmartInsight insight;
  // Visible (typed so far) part of the insight body.
  final String body;
  // True while this card's body is being typed.
  final bool typing;
  final bool expanded;
  // False while writing; taps and the expand chevron are off until done.
  final bool interactive;
  final VoidCallback onToggle;
  final ValueChanged<InsightAction> onAction;

  const _InsightCard({
    required this.insight,
    required this.body,
    required this.typing,
    required this.expanded,
    required this.interactive,
    required this.onToggle,
    required this.onAction,
  });

  /// Accent colour for the insight's tone.
  Color _toneColor(BuildContext context, AppPalette palette) =>
      switch (insight.tone) {
        InsightTone.warning => AppColors.warningOf(context),
        InsightTone.positive => palette.accent,
        InsightTone.tip => const Color(0xFF3FA7C9),
        InsightTone.info => const Color(0xFF6E93C9),
      };

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final tone = _toneColor(context, palette);
    final hasMore = insight.detail != null || insight.action != null;

    return GestureDetector(
      onTap: interactive && hasMore ? onToggle : null,
      child: GlassContainer(
        colorType: GlassColorType.surface,
        borderRadius: 22,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        // While the text is being typed the card simply grows with it; an
        // animated resize lagged behind each new line and made the cards
        // below move in steps. It animates only for expand/collapse.
        child: AnimatedSize(
          duration: typing
              ? AppMotion.instantSize
              : AppMotion.sizeOf(context, AppMotion.medium),
          curve: AppMotion.enter,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: icon, title, typed body, expand chevron.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(insight.icon, size: 20, color: tone),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontFamilyFallback: const ['Tajawal'],
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _TypedText(
                          text: body,
                          typing: typing,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontFamilyFallback: const ['Tajawal'],
                            fontSize: 13.5,
                            height: 1.55,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasMore && interactive)
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: AppMotion.of(context, AppMotion.medium),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: palette.textSecondary,
                      ),
                    ),
                ],
              ),
              // Expanded: detail box and the action button.
              if (expanded) ...[
                if (insight.detail != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      insight.detail!,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: const ['Tajawal'],
                        fontSize: 12.5,
                        height: 1.7,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
                if (insight.action != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => onAction(insight.action!),
                      style: TextButton.styleFrom(
                        foregroundColor: tone,
                        backgroundColor: tone.withValues(alpha: 0.12),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text(
                        insight.action!.label,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: ['Tajawal'],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ring gauge for the 0-100 health score, counting up as it appears.
/// Tapping it shows how each part contributed.
class _HealthGauge extends StatelessWidget {
  final int score;
  final String title;
  final String? detail;
  final bool expanded;
  final VoidCallback onToggle;

  const _HealthGauge({
    required this.score,
    required this.title,
    required this.detail,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final colors = smartGlowColors(context);
    return GestureDetector(
      onTap: detail == null ? null : onToggle,
      child: GlassContainer(
        colorType: GlassColorType.surface,
        borderRadius: 22,
        padding: const EdgeInsets.all(16),
        child: AnimatedSize(
          duration: AppMotion.sizeOf(context, AppMotion.medium),
          curve: AppMotion.enter,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ring with the counting score, title and a fixed explanation
              // line.
              Row(
                children: [
                  SizedBox.square(
                    dimension: 74,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: score / 100),
                      duration: AppMotion.of(
                        context,
                        const Duration(milliseconds: 1100),
                      ),
                      curve: AppMotion.enter,
                      builder: (context, value, _) {
                        return CustomPaint(
                          painter: _GaugePainter(
                            value: value,
                            track: palette.textPrimary.withValues(alpha: 0.08),
                            colors: colors,
                          ),
                          child: Center(
                            child: Text(
                              '${(value * 100).round()}',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontFamilyFallback: const ['Tajawal'],
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'من 100، يجمع التوفير وكفاية الرصيد واتجاه الصرف والالتزامات وانتظام التسجيل.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontFamilyFallback: const ['Tajawal'],
                            fontSize: 12,
                            height: 1.5,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (detail != null)
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: AppMotion.of(context, AppMotion.medium),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: palette.textSecondary,
                      ),
                    ),
                ],
              ),
              // Expanded: breakdown of the score.
              if (expanded && detail != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors[2].withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    detail!,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 12.5,
                      height: 1.7,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints the gauge track and a gradient arc for [value] (0-1).
class _GaugePainter extends CustomPainter {
  final double value;
  final Color track;
  final List<Color> colors;

  _GaugePainter({
    required this.value,
    required this.track,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(5);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [colors[0], colors[1], colors[2], colors[3]],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, arc);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value ||
      old.track != track ||
      !listEquals(old.colors, colors);
}
