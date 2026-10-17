// Savings goals panel: the expandable list of active goals, its header,
// the plan buttons, and the per-goal progress row.

part of 'savings_screen.dart';

/// Active goals (or empty create CTA). Collapsed it shows the first goal; a
/// tap opens the rest in place, about two and a half goals tall with the
/// remainder scrolling. The arrow under the list folds it back.
class _ActiveGoalsPanel extends StatefulWidget {
  final List<SavingsGoal> goals;
  final TransactionStore store;
  final VoidCallback onManage;
  final VoidCallback onCreate;

  const _ActiveGoalsPanel({
    required this.goals,
    required this.store,
    required this.onManage,
    required this.onCreate,
  });

  @override
  State<_ActiveGoalsPanel> createState() => _ActiveGoalsPanelState();
}

/// State of [_ActiveGoalsPanel]. Holds whether the list is expanded.
class _ActiveGoalsPanelState extends State<_ActiveGoalsPanel> {
  /// Height of one goal row, before text scaling; sizes the expanded viewport.
  static const double _goalExtent = 78;

  /// Gap between goal rows.
  static const double _goalGap = 14;

  bool _expanded = false;

  /// Opens or folds the list with a selection haptic.
  void _setExpanded(bool value) {
    if (_expanded == value) return;
    AppHaptics.selection();
    setState(() => _expanded = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    final ordered = List<SavingsGoal>.from(widget.goals)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    // No goals: header, empty state and a create button.
    if (ordered.isEmpty) {
      return GlassContainer(
        colorType: GlassColorType.surface,
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SavingsGoalsHeader(
              colors: colors,
              count: 0,
              onManage: widget.onManage,
            ),
            const SizedBox(height: 14),
            const AppEmptyState(
              icon: Icons.flag_outlined,
              title: 'لا توجد أهداف حالياً',
              compact: true,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: _CreateGoalCard(onCreate: widget.onCreate),
            ),
          ],
        ),
      );
    }

    final canExpand = ordered.length > 1;
    final expanded = _expanded && canExpand;

    Widget goalRow(int i) => _GoalProgressCard(
      goal: ordered[i],
      saved: widget.store.currentSaved(ordered[i]),
    );

    // One tree shape for both states, so the first goal keeps its state
    // (its bar does not refill) when the panel opens or closes; only the
    // added rows animate in.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final maxHeight = expanded && ordered.length > 2
        ? 2.5 * (_goalExtent * scale + _goalGap)
        : double.infinity;
    final shown = expanded ? ordered.length : 1;
    final Widget goalsBody = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        physics: expanded ? null : const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < shown; i++) ...[
              if (i > 0) const SizedBox(height: _goalGap),
              KeyedSubtree(key: ValueKey(ordered[i].id), child: goalRow(i)),
            ],
          ],
        ),
      ),
    );

    // Tapping the collapsed card expands it (or opens manage for a single goal).
    return GestureDetector(
      onTap: canExpand
          ? (expanded ? null : () => _setExpanded(true))
          : widget.onManage,
      behavior: HitTestBehavior.opaque,
      child: GlassContainer(
        colorType: GlassColorType.surface,
        borderRadius: 28,
        padding: EdgeInsets.fromLTRB(16, 15, 16, canExpand ? 4 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SavingsGoalsHeader(
              colors: colors,
              count: ordered.length,
              onManage: widget.onManage,
            ),
            const SizedBox(height: 14),
            AnimatedSize(
              duration: AppMotion.sizeOf(context, AppMotion.medium),
              curve: AppMotion.standard,
              alignment: Alignment.topCenter,
              child: goalsBody,
            ),
            if (canExpand)
              _ExpandToggle(
                expanded: expanded,
                totalCount: ordered.length,
                onTap: () => _setExpanded(!expanded),
              ),
          ],
        ),
      ),
    );
  }
}

/// Arrow under the goals list: opens the rest, or folds them back. Shows
/// the goal count while collapsed.
class _ExpandToggle extends StatelessWidget {
  final bool expanded;
  final int totalCount;
  final VoidCallback onTap;

  const _ExpandToggle({
    required this.expanded,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Semantics(
      button: true,
      label: expanded ? 'إخفاء باقي الأهداف' : 'عرض باقي الأهداف',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.fast),
                child: expanded
                    ? const SizedBox.shrink()
                    : Text(
                        'عرض كل الأهداف (\u2066$totalCount\u2069)',
                        key: ValueKey(totalCount),
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: const ['Tajawal'],
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: AppMotion.of(context, AppMotion.medium),
                curve: AppMotion.standard,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title row for the goals panel, with a manage button once goals exist.
class _SavingsGoalsHeader extends StatelessWidget {
  final AppPalette colors;
  final int count;
  final VoidCallback onManage;

  const _SavingsGoalsHeader({
    required this.colors,
    required this.count,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.wallet_rounded, size: 19, color: colors.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أهداف التوفير',
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
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (count > 0) ...[
          const SizedBox(width: 2),
          IconButton(
            onPressed: onManage,
            tooltip: 'إدارة الأهداف',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.tune_rounded,
              size: 20,
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Opens the periodic plan sheet and the completed-goals sheet. The periodic
/// button shows a check while a plan is running.
class _PlanButtonsRow extends StatelessWidget {
  final String periodicLabel;
  final bool periodicActive;
  final VoidCallback onPeriodic;
  final VoidCallback onCompleted;

  const _PlanButtonsRow({
    required this.periodicLabel,
    required this.periodicActive,
    required this.onPeriodic,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: periodicLabel,
              onTap: onPeriodic,
              leading: periodicActive
                  ? Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppPalette.of(context).accent,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: kCardGap),
          Expanded(
            child: _ActionButton(label: 'الأهداف المحققة', onTap: onCompleted),
          ),
        ],
      ),
    );
  }
}

/// Empty-state CTA that opens the create-goal sheet.
class _CreateGoalCard extends StatelessWidget {
  final VoidCallback onCreate;

  const _CreateGoalCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return GlassButton(
      onTap: onCreate,
      colorType: GlassColorType.accent,
      tintOpacity: 9,
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: Text(
          'إنشاء هدف',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontFamilyFallback: const ['Tajawal'],
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppPalette.of(context).onAccent,
          ),
        ),
      ),
    );
  }
}

/// Name, progress bar, and saved/target amounts for one active goal.
class _GoalProgressCard extends StatelessWidget {
  final SavingsGoal goal;
  final double saved;

  const _GoalProgressCard({required this.goal, required this.saved});

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    final ratio = goal.targetAmount <= 0
        ? 0.0
        : (saved / goal.targetAmount).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Goal name.
        Text(
          goal.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontFamilyFallback: const ['Tajawal'],
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),

        const SizedBox(height: 10),

        // Progress bar and percent.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _HorizontalProgress(
                ratio: ratio,
                height: 18,
                trackColor: colors.textPrimary.withValues(alpha: 0.08),
                fillColor: colors.accent,
              ),
            ),

            const SizedBox(width: 10),

            Text(
              '${(ratio * 100).round()}%',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: const ['Tajawal'],
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Saved / target amounts.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text:
                      '${formatMoney(saved)} / ${formatMoney(goal.targetAmount)}',
                ),
                TextSpan(
                  text: ' $currencyLabel',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
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
    );
  }
}

/// Rounded track with a fractionally filled accent bar that animates to
/// [ratio].
class _HorizontalProgress extends StatelessWidget {
  final double ratio;
  final double height;
  final Color trackColor;
  final Color fillColor;

  const _HorizontalProgress({
    required this.ratio,
    required this.trackColor,
    required this.fillColor,
    this.height = 18,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: trackColor)),

            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AnimatedRatio(
                value: ratio,
                builder: (context, shown) => FractionallySizedBox(
                  widthFactor: shown,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(fillColor, Colors.white, 0.18)!,
                          fillColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
