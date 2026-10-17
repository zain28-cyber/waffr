// Savings period card: the swipeable per-period savings total and its
// comparison with the previous period.

part of 'savings_screen.dart';

/// One PageView page: net saved in that window, with a percent change
/// against the previous period and arrows to step between periods.
class _PeriodSavingsCard extends StatelessWidget {
  final SavingsRange range;
  final CalendarPeriod period;
  final double amount;
  final double previousAmount;
  final bool isCurrent;
  final bool canShowNewer;
  final VoidCallback onOlder;
  final VoidCallback onNewer;

  const _PeriodSavingsCard({
    required this.range,
    required this.period,
    required this.amount,
    required this.previousAmount,
    required this.isCurrent,
    required this.canShowNewer,
    required this.onOlder,
    required this.onNewer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    final comparison = _SavingsComparison.calculate(
      current: amount,
      previous: previousAmount,
      colors: colors,
    );

    return GlassContainer(
      colorType: GlassColorType.surface,
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      height: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: newer arrow, caption and period label, older arrow.
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
                      'المبلغ الموفَّر',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: const ['Tajawal'],
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.fast),
                      child: Text(
                        isCurrent
                            ? CalendarPeriod.currentPeriodCaption(range)
                            : CalendarPeriod.rangeLabel(range, period),
                        key: ValueKey(period.start),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: const ['Tajawal'],
                          fontSize: 14,
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

          const SizedBox(height: 2),

          // Amount row, or an empty message when nothing was saved.
          if (amount <= 0)
            Text(
              'لا يوجد توفير في هذه الفترة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: const ['Tajawal'],
                fontSize: 13,
                color: colors.textPrimary.withValues(alpha: 0.55),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RollingMoney(
                      value: amount,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: const ['Tajawal'],
                        fontSize: 26,
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
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
                if (comparison != null) ...[
                  const SizedBox(width: 8),
                  Icon(comparison.icon, size: 15, color: comparison.color),
                  const SizedBox(width: 2),
                  Text(
                    comparison.text,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: comparison.color,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Percent delta badge when the previous period had savings to compare against.
class _SavingsComparison {
  final IconData icon;
  final Color color;
  final String text;

  const _SavingsComparison({
    required this.icon,
    required this.color,
    required this.text,
  });

  /// Returns the badge for [current] vs [previous], or null when there is no
  /// previous savings or no change.
  static _SavingsComparison? calculate({
    required double current,
    required double previous,
    required AppPalette colors,
  }) {
    if (previous <= 0) return null;

    final percentage = (current - previous) / previous * 100;

    if (percentage == 0) return null;

    final isPositive = percentage > 0;

    return _SavingsComparison(
      icon: isPositive
          ? Icons.trending_up_rounded
          : Icons.trending_down_rounded,
      color: isPositive ? colors.accent : colors.textPrimary,
      text:
          '${isPositive ? '+' : '−'}'
          '${percentage.abs().toStringAsFixed(0)}%',
    );
  }
}

/// Chevrons that step the savings period PageView; greyed out when disabled.
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
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        icon,
        color: enabled
            ? colors.accent
            : colors.textSecondary.withValues(alpha: 0.35),
      ),
    );
  }
}

/// Total savings card, the smart analysis tile, and the manual-save and
/// withdraw buttons in one row.
class _SplitActionRow extends StatelessWidget {
  final Widget leading;
  final Widget first;
  final Widget second;

  const _SplitActionRow({
    required this.leading,
    required this.first,
    required this.second,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: leading),

          const SizedBox(width: kCardGap),

          const SizedBox(
            width: 88,
            child: SmartAnalysisButton(
              scope: InsightScope.savings,
              style: SmartButtonStyle.tile,
            ),
          ),

          const SizedBox(width: kCardGap),

          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(child: first),
                const SizedBox(height: kCardGap),
                Expanded(child: second),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
