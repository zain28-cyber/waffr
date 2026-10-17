// SmartFactsLoader.load: the live stores are read into SmartFacts for the
// active currency (goals as GoalFacts, enabled bills as ObligationFacts,
// unbought shopping items, the streak).

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/insights/smart/smart_facts_loader.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import '../../../helpers/store_harness.dart';

void main() {
  setUp(() async {
    await setUpStores();
  });

  test('an empty device gives empty facts', () async {
    final facts = await SmartFactsLoader.load();
    expect(facts.expenses, isEmpty);
    expect(facts.goals, isEmpty);
    expect(facts.obligations, isEmpty);
    expect(facts.balance, 0);
    expect(facts.currencySymbol, 'ل.س');
    expect(facts.hasRecurringIncome, isFalse);
  });

  test('every store feeds the facts', () async {
    final ledger = TransactionStore.instance;
    await ledger.addIncome(amount: 2000, frequency: RecurringFrequency.monthly);
    await ledger.addExpense(
      amount: 100,
      category: 'طعام',
      paymentMethod: 'نقداً',
    );
    await ledger.createGoal(
      name: 'سفر',
      targetAmount: 1000,
      duration: GoalDurationPreset.threeMonths,
    );
    await ledger.saveManually(250);
    await RecurringExpenseStore.instance.addExpense(
      amount: 30,
      category: 'فواتير',
      paymentMethod: 'نقداً',
      unit: RecurringUnit.week,
      intervalCount: 1,
      note: ' إنترنت ',
    );
    await ShoppingListStore.instance.addItem('خبز');
    await ShoppingListStore.instance.addItem('حليب');
    await UsageStreakService.instance.recordToday();

    final facts = await SmartFactsLoader.load();
    expect(facts.expenses, hasLength(2));
    expect(facts.incomes, hasLength(1));
    expect(facts.savingsTransfers, hasLength(1));
    expect(facts.monthlyIncome, 2000);
    expect(facts.hasRecurringIncome, isTrue);
    expect(facts.savingsBalance, 250);
    expect(facts.balance, 2000 - 100 - 30 - 250);
    final goal = facts.goals.single;
    expect(goal.name, 'سفر');
    expect(goal.saved, 250);
    expect(goal.plannedMonths, 3);
    final bill = facts.obligations.single;
    expect(bill.name, 'إنترنت');
    expect(bill.monthlyEquivalent, closeTo(30 * 30 / 7, 1e-9));
    expect(facts.pendingShopping, 2);
    expect(facts.streakCount, 1);
    expect(facts.usageStartedAt, isNotNull);
  });
}
