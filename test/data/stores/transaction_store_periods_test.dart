// TransactionStore end-of-period work: moving a finished income period's
// leftover to savings (once, per currency), periodic goal deductions up to
// the planned count, and the cases that hold a deduction back.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/data/models/calendar_period.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import '../../helpers/ledger_builders.dart';
import '../../helpers/store_harness.dart';

void main() {
  final store = TransactionStore.instance;
  late SharedPreferences prefs;
  final now = DateTime.now();
  final lastMonth = DateTime(now.year, now.month - 1, 5);
  final lastMonthKey = CalendarPeriod.monthlyKey(lastMonth);

  setUp(() async {
    prefs = await setUpStores();
  });

  // Writes rows and goals, then loads; loading runs the due-period work.
  Future<void> load(
    List<WaffrTransaction> rows, {
    List<SavingsGoal> goals = const [],
  }) async {
    await prefs.setStringList(
      TransactionStore.transactionsKey,
      rows.map((r) => r.encode()).toList(),
    );
    await prefs.setStringList(
      TransactionStore.savingsGoalsKey,
      goals.map((g) => g.encode()).toList(),
    );
    resetStoreCaches();
    await store.ensureLoaded();
  }

  WaffrTransaction monthlyIncome(double amount, {String currency = 'SYP'}) =>
      incomeAt(
        amount,
        lastMonth,
        frequency: RecurringFrequency.monthly,
        periodKey: lastMonthKey,
        currencyCode: currency,
      );

  group('leftovers', () {
    test('a finished month moves what was not spent to savings once', () async {
      await load([
        monthlyIncome(1000),
        expenseAt(300, lastMonth.add(const Duration(days: 3))),
      ]);

      final leftover = store.savingsTransfers.single;
      expect(leftover.amount, 700);
      expect(leftover.transferKind, SavingsTransferKind.periodLeftover);
      expect(leftover.processedPeriodKey, lastMonthKey);
      expect(leftover.note, 'توفير نهاية الشهر');
      expect(store.processedPeriodTokens, contains('leftover:$lastMonthKey'));
      expect(store.balance, 0);

      await store.processDuePeriods();
      resetStoreCaches();
      await store.ensureLoaded();
      expect(store.savingsTransfers, hasLength(1), reason: 'never twice');
    });

    test(
      'the leftover is capped by the balance and skipped when spent',
      () async {
        await load([
          monthlyIncome(1000),
          expenseAt(1000, lastMonth.add(const Duration(days: 1))),
        ]);
        expect(store.savingsTransfers, isEmpty);
        expect(
          store.processedPeriodTokens,
          contains('leftover:$lastMonthKey'),
          reason: 'the period is still marked done',
        );
      },
    );

    test('other currencies get their own token', () async {
      await load([monthlyIncome(50, currency: 'USD')]);
      expect(
        store.processedPeriodTokens,
        contains('leftover:USD:$lastMonthKey'),
      );
      expect(store.savingsBalanceFor('USD'), 50);
    });

    test('the current period is left alone', () async {
      await load([
        incomeAt(
          1000,
          now,
          frequency: RecurringFrequency.monthly,
          periodKey: CalendarPeriod.monthlyKey(now),
        ),
      ]);
      expect(store.savingsTransfers, isEmpty);
      expect(store.processedPeriodTokens, isEmpty);
    });

    test('the leftover is tagged with the top active goal', () async {
      await load(
        [monthlyIncome(500)],
        goals: [
          SavingsGoal(
            id: 'g',
            name: 'g',
            targetAmount: 99999,
            createdAt: DateTime(now.year - 1),
            duration: GoalDurationPreset.year,
          ),
        ],
      );
      expect(store.savingsTransfers.single.goalId, 'g');
    });
  });

  group('periodic goals', () {
    SavingsGoal plan({
      double amount = 100,
      int count = 2,
      double? percent,
      DateTime? createdAt,
    }) => SavingsGoal(
      id: 'plan',
      name: 'خطة',
      targetAmount: 10000,
      createdAt: createdAt ?? DateTime(now.year, now.month - 3, 15),
      duration: GoalDurationPreset.threeMonths,
      isPeriodic: true,
      allocateAmount: amount,
      allocatePercent: percent,
      deductFrequency: RecurringFrequency.monthly,
      durationCount: count,
    );

    test(
      'deducts one amount per finished month, up to the planned count',
      () async {
        await load([incomeAt(1000, DateTime(now.year - 1))], goals: [plan()]);

        final deductions = store.savingsTransfers;
        expect(deductions, hasLength(2));
        expect(
          deductions.every(
            (t) =>
                t.transferKind == SavingsTransferKind.goalPeriodic &&
                t.goalId == 'plan' &&
                t.amount == 100,
          ),
          isTrue,
        );
        expect(
          store.processedPeriodTokens.where((t) => t.startsWith('goal:plan:')),
          hasLength(2),
        );
        expect(store.goalProgress(store.goals.single), 200);

        await store.processDuePeriods();
        expect(store.savingsTransfers, hasLength(2));
      },
    );

    test('stops at the first month the balance cannot cover', () async {
      await load(
        [incomeAt(150, DateTime(now.year - 1))],
        goals: [plan(count: 3)],
      );
      expect(store.savingsTransfers, hasLength(1));
      expect(store.balance, 50);
    });

    test('a percent plan waits for a configured monthly income', () async {
      await load(
        [incomeAt(1000, DateTime(now.year - 1))],
        goals: [plan(percent: 10)],
      );
      expect(store.savingsTransfers, isEmpty);

      await store.setPreferredIncomeAmount(
        frequency: RecurringFrequency.monthly,
        amount: 1000,
      );
      await store.processDuePeriods();
      expect(store.savingsTransfers, hasLength(2));
    });

    test('a plan created this month has nothing due yet', () async {
      await load(
        [incomeAt(1000, DateTime(now.year - 1))],
        goals: [plan(createdAt: DateTime(now.year, now.month, 1))],
      );
      expect(store.savingsTransfers, isEmpty);
    });
  });
}
