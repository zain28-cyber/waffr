// Report summary (part of reportscreen.dart): total spent, category
// distribution and the comparison with the previous period.

part of 'reportscreen.dart';

/// Total spent for the selected period, plus a shortcut into expense history.
class _SpendingSummary extends StatelessWidget {
  final double total;
  final VoidCallback onHistory;

  const _SpendingSummary({required this.total, required this.onHistory});

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Label and rolling total with the currency.
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الصرف',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 13.5,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: RollingMoney(
                          value: total,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontFamilyFallback: const ['Tajawal'],
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currencyLabel,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: const ['Tajawal'],
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Shortcut button into the expense history screen.
        Flexible(
          child: GlassButton(
            onTap: onHistory,
            colorType: GlassColorType.surface,
            borderRadius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'سجل المصروفات',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Category share of spending: stacked color bar plus a ranked list with %.
class _ExpenseDistribution extends StatelessWidget {
  final _ReportData report;

  const _ExpenseDistribution({required this.report});

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return GlassContainer(
      colorType: GlassColorType.surface,
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title with caption.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'توزيع المصروفات',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: const ['Tajawal'],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'النسبة من إجمالي الصرف ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (report.total <= 0 || report.categoryTotals.isEmpty)
            const _EmptyState(
              icon: Icons.stacked_bar_chart_sharp,
              message: 'ستظهر تفاصيل التصنيفات بعد تسجيل مصروف',
            )
          else ...[
            // Stacked bar, then one row per category.
            _DistributionBar(
              totals: report.categoryTotals,
              total: report.total,
            ),
            const SizedBox(height: 18),
            for (
              var index = 0;
              index < report.categoryTotals.length;
              index++
            ) ...[
              if (index > 0)
                Divider(
                  height: 18,
                  color: colors.textPrimary.withValues(alpha: 0.08),
                ),
              _CategoryRow(
                item: report.categoryTotals[index],
                total: report.total,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Single horizontal bar whose segments are proportional to category totals.
class _DistributionBar extends StatelessWidget {
  final List<_CategoryTotal> totals;
  final double total;

  const _DistributionBar({required this.totals, required this.total});

  @override
  Widget build(BuildContext context) {
    // Grows from the start edge when the card first appears. The bar is laid
    // out at full width and only uncovered, so its segments never squeeze
    // (which used to overflow the row while the width animated from 0).
    final bar = _bar(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedRatio(
      value: 1,
      builder: (context, shown) => ClipRect(
        clipper: _StartEdgeClipper(shown, rtl: rtl),
        child: bar,
      ),
    );
  }

  /// The full-width segmented bar, before clipping.
  Widget _bar(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 30,
        child: Row(
          children: [
            for (var index = 0; index < totals.length; index++) ...[
              if (index > 0) const SizedBox(width: 2),
              Expanded(
                flex: math.max(
                  1,
                  (totals[index].amount / total * 1000).round(),
                ),
                child: AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.slow),
                  curve: AppMotion.soft,
                  color: categoryChartColor(context, totals[index].category),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Keeps the part of the bar from the start edge up to [fraction] of its
/// width (the right side in RTL).
class _StartEdgeClipper extends CustomClipper<Rect> {
  final double fraction;
  final bool rtl;

  const _StartEdgeClipper(this.fraction, {required this.rtl});

  @override
  Rect getClip(Size size) {
    final width = size.width * fraction.clamp(0.0, 1.0);
    return rtl
        ? Rect.fromLTWH(size.width - width, 0, width, size.height)
        : Rect.fromLTWH(0, 0, width, size.height);
  }

  @override
  bool shouldReclip(_StartEdgeClipper old) =>
      old.fraction != fraction || old.rtl != rtl;
}

/// Icon, name, percentage, and amount for one category in the distribution
/// list.
class _CategoryRow extends StatelessWidget {
  final _CategoryTotal item;
  final double total;

  const _CategoryRow({required this.item, required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final category = categoryFor(item.category);
    final swatch = categoryChartColor(context, item.category);
    final percentage = total <= 0 ? 0 : item.amount / total * 100;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: swatch.withValues(alpha: 0.18),
          ),
          child: Icon(category.icon, size: 19, color: swatch),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            category.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: const ['Tajawal'],
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        Text(
          '${percentage.round()}%',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontFamilyFallback: const ['Tajawal'],
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              '${formatMoney(item.amount)} $currencyLabel',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: const ['Tajawal'],
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// How this period's spending compares to the previous window of the same
/// range, with the smart analysis button for reports beside it.
class _ImprovementCard extends StatelessWidget {
  final double currentTotal;
  final double previousTotal;

  const _ImprovementCard({
    required this.currentTotal,
    required this.previousTotal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    // Colour and trend icon follow the change direction.
    final comparison = SpendingImprovement.calculate(
      currentTotal: currentTotal,
      previousTotal: previousTotal,
    );
    final valueColor = switch (comparison.kind) {
      SpendingChange.positive => colors.accent,
      SpendingChange.negative => colors.textPrimary,
      SpendingChange.neutral => colors.textSecondary,
    };
    final icon = switch (comparison.kind) {
      SpendingChange.positive => Icons.trending_up_rounded,
      SpendingChange.negative => Icons.trending_down_rounded,
      SpendingChange.neutral => Icons.trending_flat_rounded,
    };

    return GlassContainer(
      colorType: GlassColorType.surface,
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نسبة التحسن',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // Without a previous period there is no number to show, so
                // the reason is the whole message instead of a bare dash.
                if (comparison.hasPercentage) ...[
                  Row(
                    children: [
                      Icon(icon, size: 20, color: valueColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          comparison.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontFamilyFallback: const ['Tajawal'],
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: valueColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  comparison.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: comparison.hasPercentage ? 12 : 13,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const SmartAnalysisButton(
            scope: InsightScope.reports,
            style: SmartButtonStyle.tile,
          ),
        ],
      ),
    );
  }
}
