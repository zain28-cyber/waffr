// Offline spending report (library root): range chips, a swipeable period
// chart (fl_chart), total spent, category distribution, and a comparison
// with the previous period.
//
// The library is split into part files: report_data (pure period math),
// report_chart, report_summary and the transaction history screen
// (transaction_history_*). TransactionHistoryScreen is public and reached
// through this file.

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:waffr/widgets/motion/motion.dart';
import 'package:waffr/widgets/motion/active_listenable_builder.dart';
import 'package:waffr/screens/shell/app_shell_scope.dart';
import 'package:waffr/widgets/containers/app_empty_state.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/models/calendar_period.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/insights/spending_improvement.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/widgets/brand/waffr_page_header.dart';
import 'package:waffr/widgets/button/glass_button.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/widgets/containers/pinned_period_scroll_view.dart';
import 'package:waffr/widgets/dialogs/waffr_date_picker.dart';
import 'package:waffr/screens/offline/report/expense_history_share.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/widgets/smart/smart_analysis_button.dart';
import 'package:waffr/core/utils/calendar_days.dart';

part 'report_chart.dart';
part 'report_data.dart';
part 'report_summary.dart';
part 'transaction_history_dialogs.dart';
part 'transaction_history_rows.dart';
part 'transaction_history_screen.dart';

/// Picks a range (day / week / month / 3 months / 6 months / year) via chips.
/// A horizontal PageView pages between older and newer periods; itemBuilder
/// builds one _SpendingChartCard per offset (not every period at once).
/// Below the chart: total spent, category bars, and a prior-period comparison.
class ReportScreen extends StatefulWidget {
  /// Creates a [ReportScreen].
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

/// State of [ReportScreen].
class _ReportScreenState extends State<ReportScreen>
    with AutomaticKeepAliveClientMixin {
  // Number of pages in the period PageView (how far back the user can swipe).
  static const int _maxPeriodOffset = 240;

  final TransactionStore _store = TransactionStore.instance;
  // Stores whose changes clear the report cache and rebuild the screen.
  late final Listenable _listenables = Listenable.merge([
    _store,
    CategoryStore.instance,
  ]);
  final PageController _periodController = PageController();
  // Selected range chip.
  _ReportRange _range = _ReportRange.month;
  // Visible page of the period PageView (0 = current period).
  int _periodOffset = 0;

  @override
  bool get wantKeepAlive => true;

  /// Reports per (range, page offset), so swiping between periods and
  /// rebuilding for a page change does not rescan the ledger. Cleared when
  /// the ledger or categories change.
  final Map<(_ReportRange, int), _ReportData> _reports = {};
  // Expense list snapshot from the store, reused until the next change.
  List<WaffrTransaction>? _expensesCache;

  List<WaffrTransaction> get _expenses => _expensesCache ??= _store.expenses;

  /// Cached report for one range and page offset; the cache is capped.
  _ReportData _reportFor(_ReportRange range, int offset) {
    if (_reports.length > 48) _reports.clear();
    return _reports.putIfAbsent((
      range,
      offset,
    ), () => _ReportData.from(_expenses, _periodFor(range, offset)));
  }

  /// Drops cached reports and the expense snapshot after a store change.
  void _invalidate() {
    _reports.clear();
    _expensesCache = null;
  }

  @override
  void initState() {
    super.initState();
    _listenables.addListener(_invalidate);
    _store.ensureLoaded();
    CategoryStore.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _listenables.removeListener(_invalidate);
    _periodController.dispose();
    super.dispose();
  }

  /// Switching range resets to the current period (offset 0).
  void _selectRange(_ReportRange range) {
    if (_range == range) return;
    setState(() {
      _range = range;
      _periodOffset = 0;
    });
    if (_periodController.hasClients) {
      _periodController.jumpToPage(0);
    }
  }

  /// Older arrow: next page of the PageView.
  void _showOlderPeriod() {
    if (_periodOffset >= _maxPeriodOffset - 1) return;
    _periodController.nextPageFor(context);
  }

  /// Newer arrow: previous page of the PageView.
  void _showNewerPeriod() {
    if (_periodOffset == 0) return;
    _periodController.previousPageFor(context);
  }

  /// Pushes the expense history screen.
  void _openExpenseHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TransactionHistoryScreen.expenses(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ActiveListenableBuilder(
      listenable: _listenables,
      builder: (context, _) {
        final expenses = _expenses;
        final report = _reportFor(_range, _periodOffset);
        final period = report.period;
        // Compare against the same elapsed span of the previous period.
        final previousPeriod = _comparablePeriod(
          _periodFor(_range, _periodOffset + 1),
          current: period,
          now: DateTime.now(),
        );
        final previousTotal = _sumExpenses(
          _expensesInPeriod(expenses, previousPeriod),
        );
        final chartHeight = (MediaQuery.sizeOf(context).height * 0.32).clamp(
          220.0,
          300.0,
        );

        // Range chips pinned on top; chart pager and cards scroll below.
        return PinnedPeriodScrollView(
          key: const PageStorageKey('report-period-scroll'),
          options: [for (final range in _ReportRange.values) range.label],
          selected: _range.label,
          onSelected: (label) {
            _selectRange(
              _ReportRange.values.firstWhere((range) => range.label == label),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: staggered([
              SizedBox(
                height: chartHeight,
                child: PageView.builder(
                  controller: _periodController,
                  itemCount: _maxPeriodOffset,
                  clipBehavior: Clip.none,
                  onPageChanged: (index) {
                    setState(() => _periodOffset = index);
                  },
                  allowImplicitScrolling: false,
                  itemBuilder: (context, offset) {
                    final pageReport = _reportFor(_range, offset);
                    return RepaintBoundary(
                      child: _SpendingChartCard(
                        report: pageReport,
                        canShowNewer: offset > 0,
                        onOlder: _showOlderPeriod,
                        onNewer: _showNewerPeriod,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: kCardGap),
              // Summary cards for the visible period.
              _SpendingSummary(
                total: report.total,
                onHistory: _openExpenseHistory,
              ),
              const SizedBox(height: kCardGap),
              _ImprovementCard(
                currentTotal: report.total,
                previousTotal: previousTotal,
              ),
              const SizedBox(height: kCardGap),
              _ExpenseDistribution(report: report),
            ]),
          ),
        );
      },
    );
  }
}
