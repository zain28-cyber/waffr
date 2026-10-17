// Report chart (part of reportscreen.dart): the swipeable period card and
// its fl_chart line chart.

part of 'reportscreen.dart';

/// One PageView page: period label, older/newer arrows, and the line chart
/// (or empty state).
class _SpendingChartCard extends StatelessWidget {
  final _ReportData report;
  // Whether a newer period exists (false on the current period).
  final bool canShowNewer;
  final VoidCallback onOlder;
  final VoidCallback onNewer;

  const _SpendingChartCard({
    required this.report,
    required this.canShowNewer,
    required this.onOlder,
    required this.onNewer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    // Built once so the reveal animation below only moves the clip.
    final chart = RepaintBoundary(
      child: _SpendingLineChart(buckets: report.chartBuckets),
    );
    return GlassContainer(
      colorType: GlassColorType.surface,
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 13),
      height: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: newer arrow, title and period label, older arrow.
          Row(
            children: [
              _PeriodArrow(
                icon: Icons.chevron_right_rounded,
                tooltip: 'الفترة الأحدث',
                enabled: canShowNewer,
                onTap: onNewer,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'الصرف خلال الفترة',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: const ['Tajawal'],
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.fast),
                      child: Text(
                        report.period.label,
                        key: ValueKey((
                          report.period.range,
                          report.period.start,
                        )),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: const ['Tajawal'],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _PeriodArrow(
                icon: Icons.chevron_left_rounded,
                tooltip: 'الفترة السابقة',
                enabled: true,
                onTap: onOlder,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Chart body, or an empty state for a period with no expenses.
          Expanded(
            child: report.expenses.isEmpty
                ? const Center(
                    child: AppEmptyState(
                      icon: Icons.show_chart_rounded,
                      title: 'لا توجد مصروفات في هذه الفترة',
                      compact: true,
                    ),
                  )
                : Directionality(
                    textDirection: TextDirection.ltr,
                    // Each period's line draws itself in from the left.
                    // The chart is built once and only the clip moves, so
                    // the chart is not rebuilt (and re-tweened) every frame.
                    child: AnimatedRatio(
                      key: ValueKey((report.period.range, report.period.start)),
                      value: 1,
                      duration: const Duration(milliseconds: 900),
                      builder: (context, shown) =>
                          RevealClip(fraction: shown, child: chart),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Chevrons that step the period PageView older or newer.
class _PeriodArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _PeriodArrow({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return IconButton(
      onPressed: enabled ? onTap : null,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        color: enabled
            ? colors.accent
            : colors.textSecondary.withValues(alpha: 0.35),
      ),
    );
  }
}

/// Maps chart buckets to FlSpot values. Y axis uses a "nice" interval so
/// labels stay round. Touch shows a tooltip with the bucket label and amount.
/// The area under the line is a light accent fill. Dots shrink when there are
/// many buckets.
class _SpendingLineChart extends StatelessWidget {
  final List<_ChartBucket> buckets;

  const _SpendingLineChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    // Scale: y rounded up to a whole number of nice intervals.
    final spots = [
      for (var index = 0; index < buckets.length; index++)
        FlSpot(index.toDouble(), buckets[index].amount),
    ];
    final peak = buckets.fold<double>(0, (max, item) {
      return item.amount > max ? item.amount : max;
    });
    final maxValue = math.max(peak, 1).toDouble();
    final yInterval = _niceInterval(maxValue);
    final maxY = math
        .max(yInterval, (maxValue / yInterval).ceil() * yInterval)
        .toDouble();
    final maxX = math.max(1, buckets.length - 1).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.none(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colors.textPrimary.withValues(alpha: 0.07),
            strokeWidth: 1,
          ),
        ),
        // Axis labels: money on the left, bucket labels along the bottom.
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > maxY) {
                  return const SizedBox.shrink();
                }
                // Skip a label that would crowd the top one.
                if (value != 0 && (value - maxY).abs() < yInterval / 3) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _axisMoney(value),
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if ((value - index).abs() > 0.05) {
                  return const SizedBox.shrink();
                }
                if (index < 0 || index >= buckets.length) {
                  return const SizedBox.shrink();
                }
                final text = buckets[index].axisLabel;
                if (text.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    text,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Touch: vertical guide, enlarged dot, and a label + amount tooltip.
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (bar, indexes) {
            return indexes
                .map(
                  (_) => TouchedSpotIndicatorData(
                    FlLine(
                      color: colors.accent.withValues(alpha: 0.35),
                      strokeWidth: 1,
                    ),
                    FlDotData(
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 4.5,
                          color: colors.accent,
                          strokeWidth: 0,
                        );
                      },
                    ),
                  ),
                )
                .toList();
          },
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipRoundedRadius: 12,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            getTooltipColor: (_) => colors.accent,
            getTooltipItems: (touched) {
              return touched.map((spot) {
                final index = spot.x.round();
                if (index < 0 || index >= buckets.length) return null;
                return LineTooltipItem(
                  '${buckets[index].label}\n'
                  '${formatMoney(spot.y)} $currencyLabel',
                  TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.surface,
                  ),
                );
              }).toList();
            },
          ),
        ),
        // The spending line with dots and a light fill under it.
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: colors.accent,
            barWidth: 2.4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: buckets.length > 16 ? 2.4 : 3.4,
                  color: colors.accent,
                  strokeWidth: 0,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: colors.accent.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
      duration: AppMotion.of(context, AppMotion.medium),
      curve: AppMotion.soft,
    );
  }
}

/// Centered icon + message used when a chart or list has nothing to show.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(icon: icon, title: message),
    );
  }
}
