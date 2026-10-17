// Offline home tab (library root): balance, add actions, spending
// distribution, recent expenses / obligations, and active savings goals.
// Each card opens the screen that holds its full details.
//
// The cards live in dashboard_* part files of this library.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/widgets/motion/motion.dart';
import 'package:waffr/widgets/motion/active_listenable_builder.dart';
import 'package:waffr/widgets/containers/app_empty_state.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/theme/app_color.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/screens/offline/home/sheets/add_expense_sheet.dart';
import 'package:waffr/screens/offline/home/sheets/add_income_sheet.dart';
import 'package:waffr/screens/offline/obligations/obligations_sheet.dart';
import 'package:waffr/screens/offline/report/reportscreen.dart';
import 'package:waffr/screens/offline/savings/sheets/shopping_list_sheet.dart';
import 'package:waffr/screens/shell/app_shell_scope.dart';
import 'package:waffr/widgets/button/glass_button.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/core/theme/app_palette.dart';

part 'dashboard_balance_card.dart';
part 'dashboard_distribution.dart';
part 'dashboard_expenses.dart';
part 'dashboard_savings_goals.dart';
part 'dashboard_sections.dart';

/// The home tab of the app shell: a scrollable stack of dashboard cards.
class HomeScreen extends StatefulWidget {
  /// Creates a [HomeScreen].
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// State of [HomeScreen].
///
/// Kept alive in the shell PageView so scroll position survives tab
/// switches. Rebuilds whenever the transaction, category, currency or
/// recurring-expense store notifies.
class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final TransactionStore _store = TransactionStore.instance;

  /// All stores the dashboard reads, merged so one builder covers them.
  late final Listenable _listenables = Listenable.merge([
    _store,
    CategoryStore.instance,
    CurrencyStore.instance,
    RecurringExpenseStore.instance,
  ]);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
    CategoryStore.instance.ensureLoaded();
    CurrencyStore.instance.ensureLoaded();
    RecurringExpenseStore.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ActiveListenableBuilder(
      listenable: _listenables,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, kFloatingNavClearance),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: staggered([
              // Balance card: links to the shopping list and the income log.
              _BalanceCard(
                balance: _store.balance,
                spent: _store.cycleSpent,
                maxBalance: _store.maxBalance,
                ratio: _store.remainingRatio,
                onShoppingList: () => showShoppingListSheet(context),
                onIncomeLog: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TransactionHistoryScreen.incomes(),
                    ),
                  );
                },
              ),
              const SizedBox(height: kCardGap),
              // Quick add buttons for income and expense.
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'إضافة دخل',
                      icon: Icons.add_circle_outline_rounded,
                      onTap: () => showAddIncomeSheet(context),
                    ),
                  ),
                  const SizedBox(width: kCardGap),
                  Expanded(
                    child: _ActionButton(
                      label: 'إضافة مصروف',
                      icon: Icons.remove_circle_outline_rounded,
                      onTap: () => showAddExpenseSheet(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kCardGap),
              // expensesByCategory is rolled up in memory from the store.
              _DistributionCard(
                totals: _store.expensesByCategory(),
                totalExpense: _store.totalExpense,
                onTap: () =>
                    AppShellScope.selectTabOf(context, AppShellTabs.report),
              ),
              const SizedBox(height: kCardGap),
              // Bottom row: recent expenses / obligations beside savings goals.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _ExpensesAndObligationsCard(
                        expenses: _store.expenses,
                        obligations: RecurringExpenseStore.instance.itemsFor(
                          CurrencyStore.instance.activeCode,
                        ),
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: kCardGap),
                    Expanded(
                      flex: 4,
                      child: _SavingGoalCard(
                        compact: true,
                        goals: _store.activeGoals,
                        store: _store,
                        onTap: () => AppShellScope.selectTabOf(
                          context,
                          AppShellTabs.savings,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
