// Home spending distribution (part of dashboard.dart): donut chart and its
// category legend.

part of 'dashboard.dart';

/// Spending share by category: legend + donut. Opens the report tab on tap.
class _DistributionCard extends StatelessWidget {
  // Per-category totals, largest first.
  final List<({String category, double amount})> totals;
  final double totalExpense;
  final VoidCallback onTap;

  const _DistributionCard({
    required this.totals,
    required this.totalExpense,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'توزيع المصروفات',
      onTap: onTap,
      caption: 'النسبة من إجمالي الصرف ',
      child: totals.isEmpty || totalExpense <= 0
          ? const _EmptyState(
              icon: Icons.pie_chart_outline_rounded,
              message: 'ستظهر النسب بعد تسجيل أول مصروف',
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _DistributionLegend(
                    totals: totals,
                    totalExpense: totalExpense,
                  ),
                ),
                const SizedBox(width: 16),
                RepaintBoundary(
                  child: _DistributionChart(
                    totals: totals,
                    totalExpense: totalExpense,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Donut of spending shares. fl_chart paints this with its pie renderer, not
/// an app-owned CustomPainter. PieChartData uses value equality, so a parent
/// rebuild with the same slices does not mark the chart dirty. RepaintBoundary
/// keeps that layer off the rest of the dashboard.
class _DistributionChart extends StatelessWidget {
  final List<({String category, double amount})> totals;
  final double totalExpense;

  const _DistributionChart({required this.totals, required this.totalExpense});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final textPrimary = palette.textPrimary;

    // The centre label shows the largest category (first in the list).
    final topShare = (totals.first.amount / totalExpense * 100).round();

    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            // The ring draws itself in once: a clear filler slice shrinks
            // while the real slices grow.
            child: AnimatedRatio(
              value: 1,
              duration: const Duration(milliseconds: 900),
              builder: (context, sweep) {
                final total = totals.fold<double>(
                  0,
                  (sum, item) => sum + item.amount,
                );
                return PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: sweep < 1 ? 0 : 2,
                    centerSpaceRadius: 34,
                    centerSpaceColor: palette.surface,
                    sections: [
                      for (var i = 0; i < totals.length; i++)
                        PieChartSectionData(
                          value: totals[i].amount * sweep,
                          color: categoryChartColor(
                            context,
                            totals[i].category,
                          ),
                          radius: i == 0 ? 18 : 15,
                          showTitle: false,
                        ),
                      if (sweep < 1)
                        PieChartSectionData(
                          value: total * (1 - sweep),
                          color: Colors.transparent,
                          radius: 15,
                          showTitle: false,
                        ),
                    ],
                  ),
                  // After the first sweep, data changes glide between values.
                  swapAnimationDuration: sweep < 1
                      ? Duration.zero
                      : AppMotion.slow,
                  swapAnimationCurve: AppMotion.enter,
                );
              },
            ),
          ),
          // Centre label: top category's share and name.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$topShare%',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              Text(
                totals.first.category,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: 10.5,
                  color: textPrimary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Legend for the donut: up to five categories with swatch and share.
class _DistributionLegend extends StatelessWidget {
  final List<({String category, double amount})> totals;
  final double totalExpense;

  const _DistributionLegend({required this.totals, required this.totalExpense});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: totals.take(5).map((item) {
        final share = (item.amount / totalExpense * 100).round();
        final swatch = categoryChartColor(context, item.category);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: swatch.withValues(alpha: 0.35),
                      blurRadius: 5,
                      spreadRadius: 0.4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                '$share%',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
