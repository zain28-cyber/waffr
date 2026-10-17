// ShoppingListStore: adding, renaming and removing items (with tombstones),
// clearing, purchases that post one expense through TransactionStore,
// reverting a purchase, prefs reload and the remote merge.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import '../../helpers/store_harness.dart';

void main() {
  final store = ShoppingListStore.instance;
  final ledger = TransactionStore.instance;

  setUp(() async {
    await setUpStores();
  });

  test('adds trimmed items newest first and ignores blanks', () async {
    await store.addItem(' خبز ');
    await store.addItem('');
    await store.addItem('حليب');
    expect(store.items.map((i) => i.name), ['حليب', 'خبز']);
    expect(store.items.every((i) => !i.isPurchased), isTrue);
  });

  test('rename validates and keeps the item', () async {
    await store.addItem('خبز');
    final id = store.items.single.id;
    expect(await store.renameItem(id, '  '), isFalse);
    expect(await store.renameItem('missing', 'x'), isFalse);
    expect(await store.renameItem(id, 'خبز'), isTrue);
    expect(await store.renameItem(id, 'كعك'), isTrue);
    expect(store.items.single.name, 'كعك');
    expect(store.items.single.id, id);
  });

  test('remove and clear log tombstones', () async {
    await store.addItem('a');
    await store.addItem('b');
    await store.addItem('c');
    final ids = store.items.map((i) => i.id).toList();

    expect(await store.removeItem('missing'), isFalse);
    expect(await store.removeItem(ids.first), isTrue);
    await store.clearAll();
    expect(store.items, isEmpty);
    expect(
      SyncTombstones.instance
          .of(SyncCollection.shoppingItems)
          .map((t) => t.clientId),
      unorderedEquals(ids),
    );
  });

  group('purchases', () {
    test('a purchase posts one tagged expense', () async {
      await ledger.addIncome(amount: 500);
      await store.addItem('رز');
      final id = store.items.single.id;

      expect(
        await store.completePurchase(itemId: id, amount: 0, category: 'طعام'),
        isFalse,
      );
      expect(
        await store.completePurchase(itemId: 'x', amount: 5, category: 'طعام'),
        isFalse,
      );
      expect(
        await store.completePurchase(itemId: id, amount: 120, category: 'طعام'),
        isTrue,
      );

      final expense = ledger.expenses.single;
      expect(expense.sourceId, 'shopping:$id');
      expect(expense.note, 'رز');
      expect(expense.paymentMethod, 'نقداً');
      final item = store.items.single;
      expect(item.isPurchased, isTrue);
      expect(item.expenseId, expense.id);
      expect(item.purchasedAt, isNotNull);

      expect(
        await store.completePurchase(itemId: id, amount: 120, category: 'طعام'),
        isTrue,
        reason: 'already bought',
      );
      expect(ledger.expenses, hasLength(1));
    });

    test('a purchase the balance cannot cover is refused', () async {
      await ledger.addIncome(amount: 50);
      await store.addItem('هاتف');
      final id = store.items.single.id;
      expect(
        await store.completePurchase(itemId: id, amount: 900, category: 'تسوق'),
        isFalse,
      );
      expect(store.items.single.isPurchased, isFalse);
      expect(ledger.expenses, isEmpty);
    });

    test('reverting clears the purchase state', () async {
      await ledger.addIncome(amount: 500);
      await store.addItem('رز');
      final id = store.items.single.id;
      await store.completePurchase(itemId: id, amount: 10, category: 'طعام');
      final expenseId = store.items.single.expenseId!;

      await store.revertPurchaseForExpense('unknown');
      expect(store.items.single.isPurchased, isTrue);
      await store.revertPurchaseForExpense(expenseId);
      expect(store.items.single.isPurchased, isFalse);
      expect(store.items.single.expenseId, isNull);
    });
  });

  test('items survive a reload', () async {
    await store.addItem('a');
    await store.addItem('b');
    resetStoreCaches();
    await store.ensureLoaded();
    expect(store.items.map((i) => i.name), ['b', 'a']);
  });

  test('applyRemoteSync merges server items newest first', () async {
    await store.applyRemoteSync(
      upserts: [
        {
          'client_id': 's1',
          'name': 'قديم',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        },
        {
          'client_id': 's2',
          'name': 'جديد',
          'created_at': '2026-02-01T00:00:00Z',
          'is_purchased': true,
          'updated_at': '2026-02-01T00:00:00Z',
        },
        {'client_id': 'bad'},
      ],
      deletes: const [],
    );
    expect(store.items.map((i) => i.id), ['s2', 's1']);
    expect(store.items.first.isPurchased, isTrue);

    await store.applyRemoteSync(
      upserts: const [],
      deletes: [SyncTombstone(clientId: 's1', deletedAt: DateTime.utc(2027))],
    );
    expect(store.items.map((i) => i.id), ['s2']);
  });
}
