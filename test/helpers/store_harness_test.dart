// The shared test harness: setUpStores really gives every test an empty
// device, and the ledger builders produce the rows they promise.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import 'ledger_builders.dart';
import 'store_harness.dart';

void main() {
  test('setUpStores wipes prefs and every store cache', () async {
    final prefs = await setUpStores();
    await TransactionStore.instance.addIncome(amount: 10);
    await CurrencyStore.instance.addCurrency('USD');
    await ShoppingListStore.instance.addItem('x');
    await SyncTombstones.instance.add(SyncCollection.transactions, 'gone');

    final fresh = await setUpStores();
    expect(identical(prefs, fresh), isTrue, reason: 'AppPrefs caches one');
    expect(fresh.getKeys(), isEmpty);
    await TransactionStore.instance.ensureLoaded();
    await CurrencyStore.instance.ensureLoaded();
    await ShoppingListStore.instance.ensureLoaded();
    await SyncTombstones.instance.ensureLoaded();
    expect(TransactionStore.instance.transactions, isEmpty);
    expect(CurrencyStore.instance.enabledCodes, ['SYP']);
    expect(ShoppingListStore.instance.items, isEmpty);
    expect(SyncTombstones.instance.of(SyncCollection.transactions), isEmpty);
  });

  test('builders make the requested rows', () {
    final at = DateTime(2026, 1, 1);
    expect(expenseAt(5, at).isExpense, isTrue);
    expect(incomeAt(5, at).isIncome, isTrue);
    expect(transferAt(5, at).transferKind, SavingsTransferKind.manual);
    expect(transferAt(5, at, out: true).isSavingsOut, isTrue);
    expect(expenseAt(1, at).id, isNot(expenseAt(1, at).id));
    final facts = buildFacts(now: at, balance: 7);
    expect(facts.balance, 7);
    expect(facts.currencySymbol, 'ل.س');
  });
}
