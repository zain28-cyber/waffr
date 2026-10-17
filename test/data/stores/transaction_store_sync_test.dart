// TransactionStore.applyRemoteSync: merging server transactions, transfers
// and goals (last write wins, deletes, local tombstones, keeping the earlier
// event time) and the settings block (period tokens, incomes, currencies,
// profile) gated by the settings timestamp.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/sync/sync_mapper.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import '../../helpers/store_harness.dart';

void main() {
  final store = TransactionStore.instance;
  late SharedPreferences prefs;

  setUp(() async {
    prefs = await setUpStores();
  });

  Future<void> apply({
    List<Map<String, dynamic>> transactions = const [],
    List<SyncTombstone> transactionDeletes = const [],
    List<Map<String, dynamic>> transfers = const [],
    List<Map<String, dynamic>> goals = const [],
    List<SyncTombstone> goalDeletes = const [],
    Map<String, dynamic>? settings,
  }) => store.applyRemoteSync(
    transactions: transactions,
    transactionDeletes: transactionDeletes,
    transfers: transfers,
    transferDeletes: const [],
    goals: goals,
    goalDeletes: goalDeletes,
    settings: settings,
  );

  Map<String, dynamic> remoteIncome(
    String id, {
    double amount = 100,
    DateTime? occurred,
    DateTime? updated,
  }) => transactionToSync(
    WaffrTransaction(
      id: id,
      type: TransactionType.income,
      amount: amount,
      dateTime: occurred ?? DateTime(2026, 1, 5),
      updatedAt: updated ?? DateTime.utc(2026, 1, 5),
    ),
  );

  test('new server rows are added and saved', () async {
    await apply(
      transactions: [remoteIncome('r1', amount: 400)],
      transfers: [
        {
          'client_id': 's1',
          'amount': '50',
          'direction': 'to_savings',
          'occurred_at': '2026-01-06T00:00:00Z',
          'updated_at': '2026-01-06T00:00:00Z',
        },
      ],
      goals: [
        goalToSync(
          SavingsGoal(
            id: 'g1',
            name: 'سفر',
            targetAmount: 1000,
            createdAt: DateTime(2026),
            duration: GoalDurationPreset.year,
          ),
        ),
      ],
    );

    expect(store.incomes.single.id, 'r1');
    expect(store.savingsTransfers.single.isSavingsIn, isTrue);
    expect(store.goals.single.id, 'g1');
    expect(store.balance, 350);

    resetStoreCaches();
    await store.ensureLoaded();
    expect(store.transactions, hasLength(2));
  });

  test('invalid server rows are skipped', () async {
    await apply(
      transactions: [
        {'client_id': 'x', 'amount': '0', 'occurred_at': '2026-01-01'},
        {'amount': '5', 'occurred_at': '2026-01-01'},
        {'client_id': 'y', 'amount': '5'},
      ],
    );
    expect(store.transactions, isEmpty);
  });

  test('only a strictly newer server row replaces the local one', () async {
    await apply(transactions: [remoteIncome('r1', amount: 100)]);
    await apply(
      transactions: [
        remoteIncome('r1', amount: 999, updated: DateTime.utc(2026, 1, 5)),
      ],
    );
    expect(store.incomes.single.amount, 100, reason: 'same stamp is an echo');

    await apply(
      transactions: [
        remoteIncome('r1', amount: 250, updated: DateTime.utc(2026, 2, 1)),
      ],
    );
    expect(store.incomes.single.amount, 250);
  });

  test('a newer server row keeps the earlier local event time', () async {
    await apply(
      transactions: [remoteIncome('r1', occurred: DateTime(2026, 1, 5, 8))],
    );
    await apply(
      transactions: [
        remoteIncome(
          'r1',
          amount: 120,
          occurred: DateTime(2026, 1, 9),
          updated: DateTime.utc(2026, 2, 1),
        ),
      ],
    );
    expect(store.incomes.single.amount, 120);
    expect(store.incomes.single.dateTime, DateTime(2026, 1, 5, 8));
  });

  test('a server delete newer than the row removes it', () async {
    await apply(transactions: [remoteIncome('r1')]);
    await apply(
      transactionDeletes: [
        SyncTombstone(clientId: 'r1', deletedAt: DateTime.utc(2026, 1, 1)),
      ],
    );
    expect(store.incomes, hasLength(1), reason: 'older delete is ignored');

    await apply(
      transactionDeletes: [
        SyncTombstone(clientId: 'r1', deletedAt: DateTime.utc(2026, 3, 1)),
      ],
    );
    expect(store.incomes, isEmpty);
  });

  test('a local delete is not resurrected by an older server row', () async {
    await apply(transactions: [remoteIncome('r1')]);
    expect(await store.undoIncome('r1'), isTrue);

    await apply(transactions: [remoteIncome('r1')]);
    expect(store.incomes, isEmpty);
  });

  test('server goal deletes remove goals', () async {
    final goal = SavingsGoal(
      id: 'g1',
      name: 'x',
      targetAmount: 10,
      createdAt: DateTime(2026),
      duration: GoalDurationPreset.month,
    );
    await apply(goals: [goalToSync(goal)]);
    await apply(
      goalDeletes: [
        SyncTombstone(clientId: 'g1', deletedAt: DateTime.utc(2027)),
      ],
    );
    expect(store.goals, isEmpty);
  });

  group('settings', () {
    test('processed period keys are merged as a union', () async {
      await prefs.setStringList(TransactionStore.processedPeriodsKey, ['a']);
      resetStoreCaches();
      await store.ensureLoaded();

      await apply(
        settings: {
          'processed_period_keys': ['b', 'a'],
          'updated_at': '2000-01-01T00:00:00Z',
        },
      );
      expect(store.processedPeriodTokens, {'a', 'b'});
    });

    test('newer settings replace incomes, currencies and profile', () async {
      await apply(
        settings: {
          'updated_at': '2026-05-01T00:00:00Z',
          'monthly_income_amount': '1800',
          'weekly_income_amount': null,
          'income_overrides_by_currency': {
            'USD': {'monthly': 200},
          },
          'enabled_currencies': ['SYP', 'USD', 'XXX'],
          'active_currency': 'USD',
          'display_name': 'سارة',
          'city': 'حمص',
        },
      );

      expect(store.monthlyIncomeOverrideFor('SYP'), 1800);
      expect(store.weeklyIncomeOverrideFor('SYP'), isNull);
      expect(store.monthlyIncomeOverrideFor('USD'), 200);
      expect(CurrencyStore.instance.enabledCodes, ['SYP', 'USD']);
      expect(CurrencyStore.instance.activeCode, 'USD');
      expect(prefs.getString('user_name'), 'سارة');
      expect(prefs.getString('user_city'), 'حمص');
      expect(
        await SyncDirty.settingsUpdatedAt(),
        DateTime.utc(2026, 5, 1),
        reason: 'the local settings time adopts the server time',
      );
    });

    test('older settings leave local values alone', () async {
      await store.setPreferredIncomeAmount(
        frequency: RecurringFrequency.monthly,
        amount: 900,
      );
      await apply(
        settings: {
          'updated_at': '2000-01-01T00:00:00Z',
          'monthly_income_amount': '5',
          'display_name': 'قديم',
        },
      );
      expect(store.configuredMonthlyIncome, 900);
      expect(prefs.getString('user_name'), isNull);
    });

    test('a zero or missing remote amount clears the local one', () async {
      await store.setPreferredIncomeAmount(
        frequency: RecurringFrequency.weekly,
        amount: 70,
      );
      await apply(
        settings: {
          'updated_at': DateTime.now()
              .toUtc()
              .add(const Duration(days: 1))
              .toIso8601String(),
          'weekly_income_amount': '0',
        },
      );
      expect(store.weeklyIncomeOverrideFor('SYP'), isNull);
    });
  });

  test('a merge that changes nothing does not notify', () async {
    await apply(transactions: [remoteIncome('r1')]);
    var calls = 0;
    void listener() => calls++;
    store.addListener(listener);
    addTearDown(() => store.removeListener(listener));

    await apply(transactions: [remoteIncome('r1')]);
    expect(calls, 0);
  });
}
