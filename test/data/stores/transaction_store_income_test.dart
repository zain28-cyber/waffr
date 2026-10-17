// TransactionStore income: adding one-off, weekly and monthly incomes, the
// carry-over to savings, configured income amounts per currency (set,
// clear, persist, sync payload), reference income and preferred cadence.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/data/models/calendar_period.dart';
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

  group('addIncome', () {
    test(
      'a one-off income has no period and sets no configured amount',
      () async {
        await store.addIncome(amount: 250, source: 'هدية');
        final income = store.incomes.single;
        expect(income.amount, 250);
        expect(income.note, 'هدية');
        expect(income.frequency, RecurringFrequency.none);
        expect(income.periodKey, isNull);
        expect(store.hasMonthlyIncome, isFalse);
        expect(store.hasRecurringIncome, isFalse);
        expect(store.configuredMonthlyIncome, isNull);
      },
    );

    test('a monthly income is stamped with its month and configured', () async {
      await store.addIncome(
        amount: 1500,
        frequency: RecurringFrequency.monthly,
      );
      final income = store.incomes.single;
      expect(income.periodKey, CalendarPeriod.monthlyKey(DateTime.now()));
      expect(store.monthlyIncomeOverrideFor('SYP'), 1500);
      expect(store.hasMonthlyIncome, isTrue);
      expect(store.hasConfiguredMonthlyIncome, isTrue);
      expect(store.configuredMonthlyIncome, 1500);
      expect(store.hasRecurringIncome, isTrue);
      expect(prefs.getDouble(TransactionStore.monthlyIncomeKey), 1500);
    });

    test('a weekly income is stamped with its week and configured', () async {
      await store.addIncome(amount: 300, frequency: RecurringFrequency.weekly);
      expect(
        store.incomes.single.periodKey,
        CalendarPeriod.weeklyKey(DateTime.now()),
      );
      expect(store.weeklyIncomeOverrideFor('SYP'), 300);
      expect(store.hasWeeklyIncome, isTrue);
      expect(store.hasMonthlyIncome, isFalse);
      expect(store.preferredIncomeFrequency, RecurringFrequency.weekly);
    });

    test(
      'moving the balance to savings first writes a carry-over transfer',
      () async {
        await store.addIncome(amount: 400);
        await store.createGoal(
          name: 'هدف',
          targetAmount: 10000,
          duration: GoalDurationPreset.year,
        );
        await store.addIncome(amount: 600, moveBalanceToSavings: true);

        final carry = store.savingsTransfers.single;
        expect(carry.amount, 400);
        expect(carry.processedPeriodKey, TransactionStore.carryOverKey);
        expect(carry.transferKind, SavingsTransferKind.manual);
        expect(carry.goalId, store.activeGoals.single.id);
        expect(store.balance, 600);
        expect(store.savingsBalance, 400);
      },
    );

    test('no carry-over when the balance is empty', () async {
      await store.addIncome(amount: 300, moveBalanceToSavings: true);
      expect(store.savingsTransfers, isEmpty);
    });
  });

  group('configured income amounts', () {
    test('invalid amounts and cadences are refused', () async {
      Future<bool> set(double amount, RecurringFrequency frequency) =>
          store.setPreferredIncomeAmount(frequency: frequency, amount: amount);

      expect(await set(0, RecurringFrequency.monthly), isFalse);
      expect(await set(-5, RecurringFrequency.monthly), isFalse);
      expect(await set(double.nan, RecurringFrequency.monthly), isFalse);
      expect(await set(double.infinity, RecurringFrequency.weekly), isFalse);
      expect(await set(100, RecurringFrequency.none), isFalse);
      expect(store.configuredMonthlyIncome, isNull);
    });

    test(
      'setting an amount posts no row and stamps the settings time',
      () async {
        expect(await SyncDirty.settingsUpdatedAt(), isNull);
        expect(
          await store.setPreferredIncomeAmount(
            frequency: RecurringFrequency.monthly,
            amount: 2000,
          ),
          isTrue,
        );
        expect(store.transactions, isEmpty);
        expect(store.configuredMonthlyIncome, 2000);
        expect(await SyncDirty.settingsUpdatedAt(), isNotNull);
        expect(await SyncDirty.isDirty(), isTrue);
      },
    );

    test('other currencies are stored in the JSON overrides', () async {
      await store.setPreferredIncomeAmount(
        frequency: RecurringFrequency.monthly,
        amount: 800,
        currencyCode: 'usd',
      );
      await store.setPreferredIncomeAmount(
        frequency: RecurringFrequency.weekly,
        amount: 150,
        currencyCode: 'USD',
      );
      await store.setPreferredIncomeAmount(
        frequency: RecurringFrequency.monthly,
        amount: 5000,
      );

      expect(store.monthlyIncomeOverrideFor('USD'), 800);
      expect(store.weeklyIncomeOverrideFor('USD'), 150);
      expect(store.incomeOverridesByCurrencyPayload, {
        'USD': {'monthly': 800.0, 'weekly': 150.0},
      });
      expect(prefs.getDouble(TransactionStore.monthlyIncomeKey), 5000);
      expect(
        prefs.getString(TransactionStore.incomeOverridesByCurrencyKey),
        contains('"USD"'),
      );

      resetStoreCaches();
      await store.ensureLoaded();
      expect(store.monthlyIncomeOverrideFor('USD'), 800);
      expect(store.weeklyIncomeOverrideFor('USD'), 150);
      expect(store.monthlyIncomeOverrideFor('SYP'), 5000);
    });

    test('no overrides outside SYP means no payload', () async {
      await store.setPreferredIncomeAmount(
        frequency: RecurringFrequency.monthly,
        amount: 5000,
      );
      expect(store.incomeOverridesByCurrencyPayload, isNull);
    });

    test('clearing removes the override but keeps income rows', () async {
      await store.addIncome(amount: 900, frequency: RecurringFrequency.monthly);
      expect(
        await store.clearPreferredIncomeAmount(
          frequency: RecurringFrequency.none,
        ),
        isFalse,
      );
      expect(
        await store.clearPreferredIncomeAmount(
          frequency: RecurringFrequency.monthly,
        ),
        isTrue,
      );
      expect(store.configuredMonthlyIncome, isNull);
      expect(prefs.getDouble(TransactionStore.monthlyIncomeKey), isNull);
      expect(store.incomes, hasLength(1));
      expect(
        store.hasMonthlyIncome,
        isTrue,
        reason: 'a recorded monthly income still counts',
      );
    });

    test('a new monthly amount updates percent-based periodic goals', () async {
      expect(
        await store.createGoal(
          name: 'خطة',
          targetAmount: 3000,
          duration: GoalDurationPreset.threeMonths,
          allocatePercent: 10,
          allocateAmount: 100,
          isPeriodic: true,
          durationCount: 3,
        ),
        isTrue,
      );
      await store.setPreferredIncomeAmount(
        frequency: RecurringFrequency.monthly,
        amount: 2500,
      );
      final goal = store.activeGoals.single;
      expect(goal.allocateAmount, 250);
      expect(goal.allocatePercent, 10);
    });
  });

  group('referenceIncome', () {
    test('the configured amount wins', () async {
      await store.setPreferredIncomeAmount(
        frequency: RecurringFrequency.weekly,
        amount: 400,
      );
      expect(store.referenceIncome(RecurringFrequency.weekly), 400);
    });

    test('falls back to this period, then the previous one', () async {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 5);
      await prefs.setStringList(TransactionStore.transactionsKey, [
        incomeAt(
          700,
          lastMonth,
          frequency: RecurringFrequency.monthly,
          periodKey: CalendarPeriod.monthlyKey(lastMonth),
        ).encode(),
      ]);
      resetStoreCaches();
      await store.ensureLoaded();

      expect(store.referenceIncome(RecurringFrequency.monthly), 700);

      await prefs.setStringList(TransactionStore.transactionsKey, [
        incomeAt(
          900,
          now,
          frequency: RecurringFrequency.monthly,
          periodKey: CalendarPeriod.monthlyKey(now),
        ).encode(),
      ]);
      resetStoreCaches();
      await store.ensureLoaded();
      expect(store.referenceIncome(RecurringFrequency.monthly), 900);
    });

    test('none uses this month of monthly incomes; nothing gives 0', () async {
      expect(store.referenceIncome(RecurringFrequency.none), 0);
      expect(store.referenceIncome(RecurringFrequency.weekly), 0);
    });
  });

  group('preferredIncomeFrequency', () {
    test(
      'defaults to monthly and follows the latest recurring income',
      () async {
        await store.ensureLoaded();
        expect(store.preferredIncomeFrequency, RecurringFrequency.monthly);

        await store.addIncome(amount: 10, frequency: RecurringFrequency.weekly);
        expect(store.preferredIncomeFrequency, RecurringFrequency.weekly);

        await store.addIncome(amount: 10);
        expect(
          store.preferredIncomeFrequency,
          RecurringFrequency.weekly,
          reason: 'one-off incomes do not change the cadence',
        );

        await store.addIncome(
          amount: 10,
          frequency: RecurringFrequency.monthly,
        );
        expect(store.preferredIncomeFrequency, RecurringFrequency.monthly);
      },
    );
  });
}
