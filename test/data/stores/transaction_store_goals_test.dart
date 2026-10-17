// TransactionStore savings goals: creation and validation, priorities and
// reordering, deletion with tombstones, progress from tagged and legacy
// transfers, automatic completion, and the periodic plan helper.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
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

  Future<bool> create(
    String name, {
    double target = 1000,
    bool periodic = false,
    double? amount,
    RecurringFrequency frequency = RecurringFrequency.monthly,
    int? durationCount,
  }) => store.createGoal(
    name: name,
    targetAmount: target,
    duration: GoalDurationPreset.sixMonths,
    isPeriodic: periodic,
    allocateAmount: amount,
    deductFrequency: frequency,
    durationCount: durationCount,
  );

  group('createGoal', () {
    test('validates name, target and periodic settings', () async {
      expect(await create('  '), isFalse);
      expect(await create('x', target: 0), isFalse);
      expect(await create('x', periodic: true), isFalse, reason: 'no amount');
      expect(
        await create(
          'x',
          periodic: true,
          amount: 50,
          frequency: RecurringFrequency.none,
          durationCount: 3,
        ),
        isFalse,
      );
      expect(
        await create('x', periodic: true, amount: 50),
        isFalse,
        reason: 'no duration count',
      );
      expect(store.goals, isEmpty);

      expect(
        await create('x', periodic: true, amount: 50, durationCount: 3),
        isTrue,
      );
      final goal = store.goals.single;
      expect(goal.isPeriodic, isTrue);
      expect(goal.allocateAmount, 50);
      expect(goal.durationCount, 3);
    });

    test('trims the name and appends goals in priority order', () async {
      await create('  أول ');
      await create('ثاني');
      await create('ثالث');
      expect(store.goals.map((g) => g.name), ['أول', 'ثاني', 'ثالث']);
      expect(store.goals.map((g) => g.priority), [0, 1, 2]);
      expect(store.goals.first.currencyCode, 'SYP');
    });

    test('a periodic amount is capped at the configured income', () async {
      await store.setPreferredIncomeAmount(
        frequency: RecurringFrequency.monthly,
        amount: 300,
      );
      await create('كبير', periodic: true, amount: 900, durationCount: 2);
      expect(store.goals.single.allocateAmount, 300);
    });

    test('a non-periodic goal keeps no per-period amount', () async {
      await create('عادي', amount: 40);
      expect(store.goals.single.allocateAmount, isNull);
      expect(store.goals.single.isPeriodic, isFalse);
    });
  });

  test('deleteGoal removes it, reindexes and logs a tombstone', () async {
    await create('a');
    await create('b');
    final first = store.goals.first.id;

    expect(await store.deleteGoal('missing'), isFalse);
    expect(await store.deleteGoal(first), isTrue);
    expect(store.goals.single.name, 'b');
    expect(store.goals.single.priority, 0);
    expect(
      SyncTombstones.instance.find(SyncCollection.savingsGoals, first),
      isNotNull,
    );
  });

  test('reorderActiveGoals moves within active goals only', () async {
    await create('a');
    await create('b');
    await create('c');

    await store.reorderActiveGoals(0, 2);
    expect(store.activeGoals.map((g) => g.name), ['b', 'c', 'a']);
    expect(store.goals.map((g) => g.priority), [0, 1, 2]);

    await store.reorderActiveGoals(5, 0);
    await store.reorderActiveGoals(0, -1);
    await store.reorderActiveGoals(1, 1);
    expect(store.activeGoals.map((g) => g.name), ['b', 'c', 'a']);

    resetStoreCaches();
    await store.ensureLoaded();
    expect(store.activeGoals.map((g) => g.name), ['b', 'c', 'a']);
  });

  group('progress', () {
    SavingsGoal goal(String id, DateTime createdAt, {double target = 1000}) =>
        SavingsGoal(
          id: id,
          name: id,
          targetAmount: target,
          createdAt: createdAt,
          duration: GoalDurationPreset.year,
          priority: id == 'old' ? 0 : 1,
        );

    Future<void> seed(
      List<WaffrTransaction> rows,
      List<SavingsGoal> goals,
    ) async {
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

    test(
      'tagged transfers after creation count, withdrawals subtract',
      () async {
        await seed(
          [
            incomeAt(5000, DateTime(2026, 1, 1)),
            transferAt(100, DateTime(2026, 1, 5), goalId: 'new'),
            transferAt(200, DateTime(2026, 2, 5), goalId: 'new'),
            transferAt(50, DateTime(2026, 2, 6), goalId: 'new', out: true),
            transferAt(80, DateTime(2026, 2, 7), goalId: 'other'),
            transferAt(
              60,
              DateTime(2026, 2, 8),
              goalId: 'new',
              currencyCode: 'USD',
            ),
          ],
          [goal('new', DateTime(2026, 2, 1))],
        );
        final saved = store.goals.single;
        expect(
          store.goalProgress(saved),
          150,
          reason: 'Jan 5 predates the goal',
        );
        expect(store.currentSaved(saved), 150);
        expect(store.goalRatio(saved), closeTo(0.15, 1e-9));
      },
    );

    test(
      'untagged transfers go to the oldest goal open at that time',
      () async {
        await seed(
          [
            incomeAt(5000, DateTime(2026, 1, 1)),
            transferAt(100, DateTime(2026, 3, 1)),
          ],
          [
            goal('old', DateTime(2026, 1, 1)),
            goal('young', DateTime(2026, 2, 1)),
          ],
        );
        final old = store.goals.firstWhere((g) => g.id == 'old');
        final young = store.goals.firstWhere((g) => g.id == 'young');
        expect(store.goalProgress(old), 100);
        expect(store.goalProgress(young), 0);
      },
    );

    test('progress never goes below zero', () async {
      await seed(
        [
          incomeAt(5000, DateTime(2026, 1, 1)),
          transferAt(10, DateTime(2026, 3, 1), goalId: 'old'),
          transferAt(90, DateTime(2026, 3, 2), goalId: 'old', out: true),
        ],
        [goal('old', DateTime(2026, 1, 1))],
      );
      expect(store.goalProgress(store.goals.single), 0);
    });

    test('a goal completes once savings reach the target', () async {
      await store.addIncome(amount: 2000);
      await create('هاتف', target: 500);

      await store.saveManually(300);
      expect(store.activeGoals, hasLength(1));

      await store.saveManually(250);
      expect(store.activeGoals, isEmpty);
      final done = store.completedGoals.single;
      expect(done.isCompleted, isTrue);
      expect(done.completedAmount, 550);
      expect(store.goalProgress(done), 550);
      expect(store.goalRatio(done), 1);
    });
  });

  group('applyPeriodicPlan', () {
    test('refuses a zero percent or income', () async {
      expect(
        await store.applyPeriodicPlan(
          percent: 0,
          duration: GoalDurationPreset.month,
          frequency: RecurringFrequency.monthly,
          income: 1000,
        ),
        isFalse,
      );
      expect(
        await store.applyPeriodicPlan(
          percent: 10,
          duration: GoalDurationPreset.month,
          frequency: RecurringFrequency.monthly,
          income: 0,
        ),
        isFalse,
      );
    });

    test('without a goal it creates a plan goal from the percent', () async {
      expect(
        await store.applyPeriodicPlan(
          percent: 15,
          duration: GoalDurationPreset.threeMonths,
          frequency: RecurringFrequency.monthly,
          income: 2000,
        ),
        isTrue,
      );
      final plan = store.activeGoals.single;
      expect(plan.name, 'توفير 15٪');
      expect(plan.allocateAmount, 300);
      expect(plan.durationCount, 3);
      expect(plan.targetAmount, 900);
      expect(plan.isPeriodic, isTrue);
    });

    test(
      'caps the percent at 100 and converts the top goal into the plan',
      () async {
        await create('سيارة', target: 99999);
        await store.applyPeriodicPlan(
          percent: 150,
          duration: GoalDurationPreset.month,
          frequency: RecurringFrequency.weekly,
          income: 400,
        );
        final goal = store.activeGoals.single;
        expect(goal.name, 'سيارة');
        expect(goal.allocatePercent, 100);
        expect(goal.allocateAmount, 400);
        expect(goal.deductFrequency, RecurringFrequency.weekly);
        expect(goal.durationCount, 4);
        expect(goal.targetAmount, 99999, reason: 'the target is kept');
      },
    );
  });
}
