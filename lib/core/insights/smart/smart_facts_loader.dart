// Reads the stores into SmartFacts for the active currency.

import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

/// Builds [SmartFacts] from the live stores.
class SmartFactsLoader {
  SmartFactsLoader._();

  /// Loads every store the analysis reads, then snapshots the active
  /// currency's figures.
  static Future<SmartFacts> load() async {
    final store = TransactionStore.instance;
    final recurring = RecurringExpenseStore.instance;
    final shopping = ShoppingListStore.instance;
    final streak = UsageStreakService.instance;
    await Future.wait([
      store.ensureLoaded(),
      recurring.ensureLoaded(),
      shopping.ensureLoaded(),
      streak.ensureLoaded(),
      CurrencyStore.instance.ensureLoaded(),
    ]);

    final code = CurrencyStore.instance.activeCode;
    return SmartFacts(
      now: deviceNow(),
      currencySymbol: CurrencyStore.instance.activeSymbol,
      expenses: store.expenses,
      incomes: store.incomes,
      savingsTransfers: store.savingsTransfers,
      balance: store.balance,
      monthlyIncome: store.configuredMonthlyIncome,
      incomeFrequency: store.preferredIncomeFrequency,
      hasRecurringIncome: store.hasRecurringIncome,
      savingsBalance: store.savingsBalance,
      goals: [
        for (final goal in store.activeGoals)
          GoalFact(
            id: goal.id,
            name: goal.name,
            target: goal.targetAmount,
            saved: store.goalProgress(goal),
            createdAt: goal.createdAt,
            plannedMonths: _months(goal.duration),
          ),
      ],
      completedGoals: store.completedGoals.length,
      obligations: [
        for (final item in recurring.itemsFor(code))
          if (item.enabled) _obligation(item),
      ],
      pendingShopping: shopping.items.where((item) => !item.isPurchased).length,
      streakCount: streak.count,
      usageStartedAt: streak.startedAt,
    );
  }

  // A goal preset as months (a week is a quarter month).
  static double _months(GoalDurationPreset preset) => switch (preset) {
    GoalDurationPreset.week => 0.25,
    GoalDurationPreset.month => 1,
    GoalDurationPreset.threeMonths => 3,
    GoalDurationPreset.sixMonths => 6,
    GoalDurationPreset.year => 12,
  };

  // A recurring bill named by its note, else its category.
  static ObligationFact _obligation(RecurringExpense item) => ObligationFact(
    name: item.note?.trim().isNotEmpty == true
        ? item.note!.trim()
        : item.category,
    amount: item.amount,
    monthlyEquivalent: item.monthlyEquivalent,
    nextDueAt: item.nextDueAt,
  );
}
