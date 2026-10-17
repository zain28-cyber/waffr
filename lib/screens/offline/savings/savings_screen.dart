// Savings hub: period net-saved card, total balance, active goals, and entry
// points that open create / manual save / withdraw / shopping / recurring sheets.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/motion/motion.dart';
import 'package:waffr/widgets/motion/active_listenable_builder.dart';
import 'package:waffr/screens/shell/app_shell_scope.dart';
import 'package:waffr/widgets/containers/app_empty_state.dart';
import 'package:waffr/data/models/calendar_period.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/screens/offline/savings/sheets/completed_goals_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/create_goal_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/manage_goals_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/manual_save_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/periodic_goals_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/shopping_list_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/withdraw_savings_sheet.dart';
import 'package:waffr/widgets/button/glass_button.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/widgets/containers/pinned_period_scroll_view.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/widgets/smart/smart_analysis_button.dart';

part 'savings_goals_panel.dart';
part 'savings_period_card.dart';
part 'savings_total_card.dart';

/// Savings tab: range chips over a swipeable net-saved period card, plan
/// shortcuts, active goals, total savings with save / withdraw actions, and
/// the shopping list preview.
///
/// Reads [TransactionStore] and opens the sheets in `sheets/`.
class SavingsScreen extends StatefulWidget {
  /// Creates a [SavingsScreen].
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

/// State of [SavingsScreen]. Owns the period pager controller and is kept
/// alive across tab switches.
class _SavingsScreenState extends State<SavingsScreen>
    with AutomaticKeepAliveClientMixin {
  /// How many periods back the pager reaches (page 0 is the current one).
  static const int _maxPeriodOffset = 240;

  final TransactionStore _store = TransactionStore.instance;

  /// Pages through periods; page index = how many periods back.
  final PageController _periodController = PageController();

  SavingsRange _range = SavingsRange.month;

  /// Page currently shown; read by the arrow handlers only.
  int _periodOffset = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Load the ledger, then apply any end-of-period deductions that fell due.
    _store.ensureLoaded().then((_) => _store.processDuePeriods());
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  /// Switches the range and jumps the period pager back to the current window.
  void _selectRange(SavingsRange range) {
    if (_range == range) return;

    setState(() {
      _range = range;
      _periodOffset = 0;
    });

    if (_periodController.hasClients) {
      _periodController.jumpToPage(0);
    }
  }

  /// Steps the pager one period back, stopping at the oldest page.
  void _showOlderPeriod() {
    if (_periodOffset >= _maxPeriodOffset - 1) return;

    _periodController.nextPageFor(context);
  }

  /// Steps the pager one period forward, stopping at the current one.
  void _showNewerPeriod() {
    if (_periodOffset == 0) return;

    _periodController.previousPageFor(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ActiveListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final goals = _store.activeGoals;

        return PinnedPeriodScrollView(
          key: const PageStorageKey('savings-period-scroll'),
          options: [for (final range in SavingsRange.values) range.label],
          selected: _range.label,
          onSelected: (label) {
            _selectRange(
              SavingsRange.values.firstWhere((range) => range.label == label),
            );
          },
          child: Column(
            children: staggered([
              // Swipeable net-saved card, one page per period.
              SizedBox(
                height: 108,
                child: PageView.builder(
                  controller: _periodController,
                  itemCount: _maxPeriodOffset,
                  clipBehavior: Clip.none,
                  // Only the arrows read the offset; no rebuild needed.
                  onPageChanged: (index) => _periodOffset = index,
                  itemBuilder: (context, offset) {
                    final pagePeriod = CalendarPeriod.forRange(_range, offset);

                    final previousPeriod = CalendarPeriod.forRange(
                      _range,
                      offset + 1,
                    );

                    return _PeriodSavingsCard(
                      range: _range,
                      period: pagePeriod,
                      amount: _store.savingsNetDuring(
                        pagePeriod.start,
                        pagePeriod.end,
                      ),
                      previousAmount: _store.savingsNetDuring(
                        previousPeriod.start,
                        previousPeriod.end,
                      ),
                      isCurrent: offset == 0,
                      canShowNewer: offset > 0,
                      onOlder: _showOlderPeriod,
                      onNewer: _showNewerPeriod,
                    );
                  },
                ),
              ),

              const SizedBox(height: kCardGap),

              // Periodic plans and completed goals shortcuts.
              _PlanButtonsRow(
                periodicLabel: _store.hasActivePeriodicPlan
                    ? 'خطة جارية'
                    : 'خطط التوفير',
                periodicActive: _store.hasActivePeriodicPlan,
                onPeriodic: () => showPeriodicGoalsSheet(context),
                onCompleted: () => showCompletedGoalsSheet(context),
              ),

              const SizedBox(height: kCardGap),

              // Active goals with manage / create entry points.
              _ActiveGoalsPanel(
                goals: goals,
                store: _store,
                onManage: () => showManageGoalsSheet(context),
                onCreate: () => showCreateGoalSheet(context),
              ),

              const SizedBox(height: kCardGap),

              // Total savings, smart analysis tile, save and withdraw buttons.
              _SplitActionRow(
                leading: _TotalSavingsCard(total: _store.savingsBalance),
                first: _ActionButton(
                  label: 'توفير مبلغ',
                  onTap: () => showManualSaveSheet(context),
                ),
                second: _ActionButton(
                  label: 'سحب إلى الرصيد',
                  onTap: () => showWithdrawSavingsSheet(context),
                ),
              ),

              const SizedBox(height: kCardGap),

              // Shopping list preview; opens the full list sheet.
              const ShoppingListPreviewCard(),

              const SizedBox(height: 12),
            ]),
          ),
        );
      },
    );
  }
}
