// Home savings goals (part of dashboard.dart): a swipeable card with one
// page per active goal.

part of 'dashboard.dart';

/// Active goals in a PageView, one goal per page; swipe to move between them.
/// A tap opens the savings tab.
class _SavingGoalCard extends StatefulWidget {
  final bool compact;
  final List<SavingsGoal> goals;
  // Read for each goal's saved amount.
  final TransactionStore store;
  final VoidCallback onTap;

  const _SavingGoalCard({
    this.compact = false,
    required this.goals,
    required this.store,
    required this.onTap,
  });

  @override
  State<_SavingGoalCard> createState() => _SavingGoalCardState();
}

/// State of [_SavingGoalCard]. Owns the [PageController] and tracks the
/// visible goal by id so list changes do not jump to another goal.
class _SavingGoalCardState extends State<_SavingGoalCard> {
  late final PageController _controller;
  // Id of the goal on the visible page.
  String? _goalId;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    if (widget.goals.isNotEmpty) {
      _goalId = widget.goals.first.id;
    }
  }

  @override
  void didUpdateWidget(covariant _SavingGoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVisibleGoal();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Keeps the pager on the same goal id when the goals list changes.
  void _syncVisibleGoal() {
    final goals = widget.goals;
    if (goals.isEmpty) {
      _goalId = null;
      return;
    }

    var index = goals.indexWhere((goal) => goal.id == _goalId);
    if (index < 0) {
      index = 0;
    }
    _goalId = goals[index].id;

    if (!_controller.hasClients) {
      return;
    }

    final current = _controller.page?.round() ?? _controller.initialPage;
    if (current == index) {
      return;
    }

    // Jump after the frame, once the PageView has the new item count.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      final length = widget.goals.length;
      if (length == 0) {
        return;
      }
      final next = index.clamp(0, length - 1);
      if ((_controller.page?.round() ?? _controller.initialPage) != next) {
        _controller.jumpToPage(next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final accent = palette.accent;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;

    final compact = widget.compact;
    final goals = widget.goals;

    // No active goal: title and a placeholder message.
    if (goals.isEmpty) {
      return _SectionCard(
        title: 'هدف التوفير',
        compact: compact,
        centerChild: compact,
        onTap: widget.onTap,
        child: Text(
          'لا يوجد هدف حالياً',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontFamilyFallback: ['Tajawal'],
            fontSize: compact ? 13 : 15,
            fontWeight: FontWeight.w700,
            color: textSecondary,
          ),
        ),
      );
    }

    final inactiveDot = textPrimary.withValues(alpha: 0.22);

    return _SectionCard(
      title: 'هدف التوفير',
      compact: compact,
      centerChild: compact,
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: compact ? 128 : 150,
            // Swallows horizontal scroll notifications so the shell's tab
            // PageView does not also react to this card's swipe.
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                return notification.metrics.axis == Axis.horizontal;
              },
              child: PageView.builder(
                controller: _controller,
                itemCount: goals.length,
                physics: const PageScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                onPageChanged: (index) {
                  _goalId = goals[index].id;
                },
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  final saved = widget.store.currentSaved(goal);
                  final target = goal.targetAmount;
                  final ratio = target <= 0
                      ? 0.0
                      : (saved / target).clamp(0.0, 1.0);

                  return Center(
                    child: _SavingGoalPage(
                      compact: compact,
                      ratio: ratio,
                      saved: saved,
                      target: target,
                      accent: accent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          _PageDots(
            controller: _controller,
            count: goals.length,
            activeColor: accent,
            inactiveColor: inactiveDot,
          ),
        ],
      ),
    );
  }
}

/// Page dots under a dashboard pager. Follows the same direction as the
/// PageView, so the highlighted dot stays aligned in RTL.
class _PageDots extends StatelessWidget {
  final PageController controller;
  final int count;
  final Color activeColor;
  final Color inactiveColor;

  const _PageDots({
    required this.controller,
    required this.count,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = controller.hasClients
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < count; index++)
              _PageDot(
                selected: 1 - (page - index).abs().clamp(0.0, 1.0),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
          ],
        );
      },
    );
  }
}

/// One pager dot; [selected] (0-1) widens it and blends in the active colour.
class _PageDot extends StatelessWidget {
  final double selected;
  final Color activeColor;
  final Color inactiveColor;

  const _PageDot({
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final width = 6 + (8 * selected);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        width: width,
        height: 6,
        decoration: BoxDecoration(
          color: Color.lerp(inactiveColor, activeColor, selected),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// One savings goal: vertical progress bar, percentage, and saved / target.
class _SavingGoalPage extends StatelessWidget {
  final bool compact;
  final double ratio;
  final double saved;
  final double target;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  const _SavingGoalPage({
    required this.compact,
    required this.ratio,
    required this.saved,
    required this.target,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VerticalProgress(
              ratio: ratio,
              width: compact ? 26 : 30,
              height: compact ? 92 : 96,
              trackColor: textPrimary.withValues(alpha: 0.08),
              fillColor: accent,
            ),
            SizedBox(width: compact ? 6 : 10),
            Flexible(
              child: Text(
                '${(ratio * 100).round()}%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: compact ? 11 : 12.5,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${formatMoney(saved)} / ${formatMoney(target)}',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: compact ? 14 : 17,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded bar that fills from the bottom by [ratio] (0-1), animated.
class _VerticalProgress extends StatelessWidget {
  final double ratio;
  final double width;
  final double height;
  final Color trackColor;
  final Color fillColor;

  const _VerticalProgress({
    required this.ratio,
    required this.trackColor,
    required this.fillColor,
    this.width = 26,
    this.height = 92,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: trackColor)),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedRatio(
                value: ratio,
                builder: (context, shown) => FractionallySizedBox(
                  heightFactor: shown,
                  child: Container(width: width, color: fillColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
