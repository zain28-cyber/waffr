// ProfileSnapshot.fromStore (counts across currencies, money in the active
// one) and earliestUsageDate over ledger rows and goals.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/insights/profile_snapshot.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import '../../helpers/ledger_builders.dart';
import '../../helpers/store_harness.dart';

void main() {
  final store = TransactionStore.instance;

  setUp(() async {
    final prefs = await setUpStores();
    await prefs.setStringList(TransactionStore.transactionsKey, [
      incomeAt(1000, DateTime(2026, 3, 1)).encode(),
      incomeAt(50, DateTime(2026, 3, 2), currencyCode: 'USD').encode(),
      expenseAt(100, DateTime(2026, 3, 3)).encode(),
      expenseAt(5, DateTime(2026, 3, 4), currencyCode: 'USD').encode(),
      transferAt(200, DateTime(2026, 3, 5)).encode(),
      transferAt(20, DateTime(2026, 3, 6), out: true).encode(),
    ]);
    await prefs.setStringList(TransactionStore.savingsGoalsKey, [
      SavingsGoal(
        id: 'g',
        name: 'g',
        targetAmount: 10000,
        createdAt: DateTime(2026, 2, 1),
        duration: GoalDurationPreset.year,
      ).encode(),
    ]);
    resetStoreCaches();
    await store.ensureLoaded();
  });

  test('counts every currency, sums only the active one', () {
    final snapshot = ProfileSnapshot.fromStore(store);
    expect(snapshot.incomeCount, 2);
    expect(snapshot.expenseCount, 2);
    expect(snapshot.savingsCount, 1, reason: 'withdrawals are not counted');
    expect(snapshot.goalCount, 1);
    expect(snapshot.spent, 100);
    expect(snapshot.saved, 200);
  });

  test('earliest usage looks at goals too', () {
    expect(earliestUsageDate(store), DateTime(2026, 2, 1));
  });

  test('an empty store has no usage date', () async {
    await setUpStores();
    await store.ensureLoaded();
    expect(earliestUsageDate(store), isNull);
    final snapshot = ProfileSnapshot.fromStore(store);
    expect(snapshot.spent, 0);
    expect(snapshot.goalCount, 0);
  });
}
