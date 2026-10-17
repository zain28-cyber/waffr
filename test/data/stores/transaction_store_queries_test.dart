// TransactionStore read side: rows per type and currency, totals, balances,
// savings balance and per-window savings, category totals, goal lists, and
// the read-only ledger view.

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

  // Writes [rows] (and [goals]) to prefs and reloads the store from them.
  Future<void> seed(
    List<WaffrTransaction> rows, {
    List<SavingsGoal> goals = const [],
  }) async {
    await prefs.setStringList(
      TransactionStore.transactionsKey,
      rows.map((row) => row.encode()).toList(),
    );
    await prefs.setStringList(
      TransactionStore.savingsGoalsKey,
      goals.map((goal) => goal.encode()).toList(),
    );
    resetStoreCaches();
    await store.ensureLoaded();
  }

  test('an empty ledger has zero everything', () async {
    await store.ensureLoaded();
    expect(store.isLoaded, isTrue);
    expect(store.transactions, isEmpty);
    expect(store.balance, 0);
    expect(store.totalExpense, 0);
    expect(store.savingsBalance, 0);
    expect(store.expensesByCategory(), isEmpty);
    expect(store.canDeduct(1), isFalse);
  });

  test('rows are split by type and sorted newest first', () async {
    final day = DateTime(2026, 1, 10);
    await seed([
      incomeAt(1000, day, id: 'i1'),
      expenseAt(100, day.add(const Duration(hours: 1)), id: 'e1'),
      expenseAt(50, day.add(const Duration(hours: 3)), id: 'e2'),
      transferAt(200, day.add(const Duration(hours: 2)), id: 's1'),
      transferAt(30, day.add(const Duration(hours: 4)), id: 's2', out: true),
    ]);

    expect(store.transactions.map((t) => t.id), ['s2', 'e2', 's1', 'e1', 'i1']);
    expect(store.expenses.map((t) => t.id), ['e2', 'e1']);
    expect(store.incomes.map((t) => t.id), ['i1']);
    expect(store.savingsTransfers.map((t) => t.id), ['s2', 's1']);
  });

  test('balance is income minus expenses minus net savings', () async {
    final day = DateTime(2026, 1, 10);
    await seed([
      incomeAt(1000, day),
      expenseAt(100, day),
      expenseAt(50, day),
      transferAt(200, day),
      transferAt(30, day, out: true),
    ]);

    expect(store.totalIncomeFor('SYP'), 1000);
    expect(store.totalExpense, 150);
    expect(store.totalSavingsInFor('SYP'), 200);
    expect(store.totalSavingsOutFor('syp'), 30);
    expect(store.savingsBalance, 170);
    expect(store.balance, 680);
    expect(store.canDeduct(680), isTrue);
    expect(store.canDeduct(680.01), isFalse);
    expect(store.canDeduct(0), isFalse);
    expect(store.canDeduct(-1), isFalse);
  });

  test('savings balance never goes below zero', () async {
    final day = DateTime(2026, 1, 10);
    await seed([
      incomeAt(100, day),
      transferAt(10, day),
      transferAt(40, day, out: true),
    ]);
    expect(store.savingsBalance, 0);
    expect(store.balance, 100, reason: 'over-withdrawal adds nothing');
  });

  test('every figure is kept per currency', () async {
    final day = DateTime(2026, 1, 10);
    await seed([
      incomeAt(1000, day),
      incomeAt(50, day, currencyCode: 'USD'),
      expenseAt(20, day, currencyCode: 'USD', category: 'تسوق'),
    ]);

    expect(store.balance, 1000, reason: 'SYP is active');
    expect(store.balanceFor('usd'), 30);
    expect(store.expensesFor('USD'), hasLength(1));
    expect(store.incomesFor('USD').single.amount, 50);
    expect(store.expenses, isEmpty);
    expect(store.canDeduct(30, currencyCode: 'USD'), isTrue);
    expect(store.canDeduct(31, currencyCode: 'USD'), isFalse);
    expect(
      store.expensesByCategory(currencyCode: 'USD').single.category,
      'تسوق',
    );
    expect(store.balanceFor('EUR'), 0);
  });

  test('expenses by category are summed and sorted largest first', () async {
    final day = DateTime(2026, 1, 10);
    await seed([
      incomeAt(1000, day),
      expenseAt(30, day, category: 'طعام'),
      expenseAt(80, day, category: 'مواصلات'),
      expenseAt(40, day, category: 'طعام'),
      WaffrTransaction(
        id: 'none',
        type: TransactionType.expense,
        amount: 5,
        dateTime: day,
      ),
    ]);

    final totals = store.expensesByCategory();
    expect(totals.map((e) => e.category), ['مواصلات', 'طعام', 'أخرى']);
    expect(totals.map((e) => e.amount), [80, 70, 5]);
  });

  test('net savings inside a window are floored at zero', () async {
    await seed([
      incomeAt(1000, DateTime(2026, 1, 1)),
      transferAt(100, DateTime(2026, 2, 3)),
      transferAt(40, DateTime(2026, 2, 20), out: true),
      transferAt(500, DateTime(2026, 3, 1)),
      transferAt(70, DateTime(2026, 4, 2), out: true),
    ]);

    expect(store.savingsNetDuring(DateTime(2026, 2), DateTime(2026, 3)), 60);
    expect(
      store.savingsNetDuring(DateTime(2026, 3), DateTime(2026, 4)),
      500,
      reason: 'the end is exclusive, the start inclusive',
    );
    expect(store.savingsNetDuring(DateTime(2026, 4), DateTime(2026, 5)), 0);
    expect(
      store.savingsNetDuring(
        DateTime(2026, 2),
        DateTime(2026, 3),
        currencyCode: 'USD',
      ),
      0,
    );
  });

  test('the ledger view is read-only', () async {
    await seed([incomeAt(10, DateTime(2026))]);
    expect(
      () => store.transactions.add(incomeAt(1, DateTime(2026))),
      throwsUnsupportedError,
    );
    expect(() => store.goals.clear(), throwsUnsupportedError);
  });

  group('goal lists', () {
    SavingsGoal goal(
      String id, {
      int priority = 0,
      String currency = 'SYP',
      DateTime? completedAt,
      bool periodic = false,
    }) => SavingsGoal(
      id: id,
      name: id,
      targetAmount: 100,
      currencyCode: currency,
      createdAt: DateTime(2026, 1, 1),
      duration: GoalDurationPreset.month,
      completedAt: completedAt,
      completedAmount: completedAt == null ? null : 100,
      isPeriodic: periodic,
      allocateAmount: periodic ? 10 : null,
      priority: priority,
    );

    test('active, completed and periodic goals per currency', () async {
      await seed(
        [],
        goals: [
          goal('a', priority: 0),
          goal('b', priority: 1, periodic: true),
          goal('usd', priority: 2, currency: 'USD'),
          goal('done1', priority: 3, completedAt: DateTime(2026, 2, 1)),
          goal('done2', priority: 4, completedAt: DateTime(2026, 3, 1)),
        ],
      );

      expect(store.goals.map((g) => g.id), ['a', 'b', 'usd', 'done1', 'done2']);
      expect(store.activeGoals.map((g) => g.id), ['a', 'b']);
      expect(store.activeGoalsFor('USD').map((g) => g.id), ['usd']);
      expect(store.completedGoals.map((g) => g.id), ['done2', 'done1']);
      expect(store.activePeriodicGoal?.id, 'b');
      expect(store.hasActivePeriodicPlan, isTrue);
    });

    test('no periodic plan without a periodic goal', () async {
      await seed([], goals: [goal('a')]);
      expect(store.activePeriodicGoal, isNull);
      expect(store.hasActivePeriodicPlan, isFalse);
    });
  });
}
