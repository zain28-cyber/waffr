// TransactionStore loading and saving: a full round trip through prefs,
// the derived figures it writes, and migrations of older formats (pipe
// separated expenses, rows without currency, the single legacy goal,
// goals without priorities, corrupt rows).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import '../../helpers/ledger_builders.dart';
import '../../helpers/store_harness.dart';

void main() {
  final store = TransactionStore.instance;
  late SharedPreferences prefs;

  setUp(() async {
    prefs = await setUpStores();
  });

  Future<void> reload() async {
    resetStoreCaches();
    await store.ensureLoaded();
  }

  test('ledger, goals and configured incomes survive a reload', () async {
    await store.addIncome(amount: 2000, frequency: RecurringFrequency.monthly);
    await store.addExpense(
      amount: 150,
      category: 'صحة',
      paymentMethod: 'بطاقة',
      note: 'دواء',
    );
    await store.createGoal(
      name: 'سفر',
      targetAmount: 3000,
      duration: GoalDurationPreset.year,
    );
    await store.saveManually(500);
    await store.setPreferredIncomeAmount(
      frequency: RecurringFrequency.weekly,
      amount: 90,
      currencyCode: 'EUR',
    );
    final idsBefore = store.transactions.map((t) => t.id).toList();

    await reload();

    expect(store.transactions.map((t) => t.id), idsBefore);
    expect(store.expenses.single.note, 'دواء');
    expect(store.expenses.single.paymentMethod, 'بطاقة');
    expect(store.goals.single.name, 'سفر');
    expect(store.goalProgress(store.goals.single), 500);
    expect(store.configuredMonthlyIncome, 2000);
    expect(store.weeklyIncomeOverrideFor('EUR'), 90);
    expect(store.balance, 1350);
  });

  test('saving writes the derived balances for home widgets', () async {
    await store.addIncome(amount: 1000);
    await store.saveManually(250);
    expect(prefs.getDouble(TransactionStore.balanceKey), 750);
    expect(prefs.getDouble(TransactionStore.savingsBalanceKey), 250);
    expect(prefs.getDouble(TransactionStore.maxBalanceKey), store.maxBalance);
    expect(prefs.getStringList(TransactionStore.transactionsKey), hasLength(2));
  });

  test('pre-JSON expenses are migrated once', () async {
    await prefs.setStringList(TransactionStore.legacyExpensesKey, [
      '25.5|قهوة|2025-05-01T10:00:00.000',
      '10||2025-05-02T10:00:00.000',
      '0|zero|2025-05-03',
      'junk',
      '7',
    ]);
    await reload();

    final expenses = store.expenses;
    expect(expenses.map((e) => e.amount), unorderedEquals([25.5, 10, 7]));
    expect(expenses.every((e) => e.category == 'أخرى'), isTrue);
    final coffee = expenses.firstWhere((e) => e.amount == 25.5);
    expect(coffee.note, 'قهوة');
    expect(coffee.dateTime, DateTime(2025, 5, 1, 10));
    expect(expenses.firstWhere((e) => e.amount == 10).note, isNull);
    expect(
      prefs.getStringList(TransactionStore.transactionsKey),
      hasLength(3),
      reason: 'migrated rows are saved in the new format',
    );

    await reload();
    expect(store.expenses, hasLength(3));
  });

  test('rows saved before currencies are stamped SYP and re-saved', () async {
    await prefs.setStringList(TransactionStore.transactionsKey, [
      jsonEncode({
        'id': 'old',
        'type': 'income',
        'amount': 40,
        'dateTime': '2025-01-01T00:00:00.000',
      }),
      'not json',
    ]);
    await reload();

    expect(store.incomes.single.currencyCode, 'SYP');
    final stored = prefs.getStringList(TransactionStore.transactionsKey)!;
    expect(stored, hasLength(1), reason: 'the corrupt row is dropped');
    expect(stored.single, contains('"currencyCode":"SYP"'));
  });

  test('the single legacy goal becomes the goal list', () async {
    await prefs.setString(
      TransactionStore.legacySavingsGoalKey,
      jsonEncode({
        'id': 'legacy',
        'name': 'قديم',
        'targetAmount': 100,
        'priority': 4,
      }),
    );
    await reload();

    expect(store.goals.single.id, 'legacy');
    expect(store.goals.single.priority, 0);
    expect(prefs.getStringList(TransactionStore.savingsGoalsKey), hasLength(1));
  });

  test('goals without priorities are ordered and written back', () async {
    String raw(String id, {int? priority}) => jsonEncode({
      'id': id,
      'name': id,
      'targetAmount': 10,
      'currencyCode': 'SYP',
      'priority': ?priority,
    });
    await prefs.setStringList(TransactionStore.savingsGoalsKey, [
      raw('b', priority: 5),
      raw('a'),
      raw('c', priority: 2),
    ]);
    await reload();

    expect(store.goals.map((g) => g.id), ['a', 'c', 'b']);
    expect(store.goals.map((g) => g.priority), [0, 1, 2]);
    final stored = prefs.getStringList(TransactionStore.savingsGoalsKey)!;
    expect(stored.every((row) => row.contains('"priority"')), isTrue);
  });

  test('processed period tokens are loaded', () async {
    await prefs.setStringList(TransactionStore.processedPeriodsKey, [
      'leftover:m:2020-01',
    ]);
    await reload();
    expect(store.processedPeriodTokens, {'leftover:m:2020-01'});
    expect(() => store.processedPeriodTokens.add('x'), throwsUnsupportedError);
  });

  test('configured incomes are read from prefs, ignoring bad values', () async {
    await prefs.setDouble(TransactionStore.monthlyIncomeKey, 1200);
    await prefs.setDouble(TransactionStore.weeklyIncomeKey, -3);
    await prefs.setString(
      TransactionStore.incomeOverridesByCurrencyKey,
      jsonEncode({
        'usd': {'monthly': '300', 'weekly': 0},
        'SYP': {'monthly': 1},
        'EUR': 'bad',
      }),
    );
    await reload();

    expect(store.monthlyIncomeOverrideFor('SYP'), 1200);
    expect(store.weeklyIncomeOverrideFor('SYP'), isNull);
    expect(store.monthlyIncomeOverrideFor('USD'), 300);
    expect(store.weeklyIncomeOverrideFor('USD'), isNull);
    expect(store.monthlyIncomeOverrideFor('EUR'), isNull);
  });

  test('a malformed overrides JSON is ignored', () async {
    await prefs.setString(TransactionStore.incomeOverridesByCurrencyKey, '{');
    await reload();
    expect(store.incomeOverridesByCurrencyPayload, isNull);
  });

  test('the hydration hook runs once per load', () async {
    var calls = 0;
    store.onHydrated = () async => calls++;
    addTearDown(() => store.onHydrated = null);

    await reload();
    await store.ensureLoaded();
    expect(calls, 1);
  });

  test('resetCache empties memory until the next load', () async {
    await store.addIncome(amount: 10);
    store.resetCache();
    expect(store.isLoaded, isFalse);
    expect(store.transactions, isEmpty);
    await store.ensureLoaded();
    expect(store.incomes, hasLength(1));
  });

  test('a migrated legacy expense dated in the past keeps its date', () async {
    final row = expenseAt(5, DateTime(2024, 2, 2));
    await prefs.setStringList(TransactionStore.transactionsKey, [row.encode()]);
    await reload();
    expect(store.expenses.single.dateTime, DateTime(2024, 2, 2));
  });
}
