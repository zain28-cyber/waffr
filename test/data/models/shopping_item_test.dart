// ShoppingItem: prefs and /sync round trips, required fields, purchase
// clearing in copyWith and the default list id on synced rows.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/sync_mapper.dart';
import 'package:waffr/data/models/shopping_item.dart';

void main() {
  final bought = ShoppingItem(
    id: 's1',
    name: 'حليب',
    createdAt: DateTime(2026, 4, 1, 10),
    isPurchased: true,
    purchasedAt: DateTime(2026, 4, 2, 11),
    expenseId: 'e1',
    updatedAt: DateTime.utc(2026, 4, 2, 12),
  );

  test('prefs round trip', () {
    final back = ShoppingItem.decode(bought.encode())!;
    expect(back.id, 's1');
    expect(back.name, 'حليب');
    expect(back.createdAt, DateTime(2026, 4, 1, 10));
    expect(back.isPurchased, isTrue);
    expect(back.purchasedAt, DateTime(2026, 4, 2, 11));
    expect(back.expenseId, 'e1');
    expect(back.updatedAt, DateTime.utc(2026, 4, 2, 12));
  });

  test('sync round trip and the default list', () {
    final json = bought.toSyncJson();
    expect(json['list_client_id'], defaultShoppingListId);
    expect(json['quantity'], 1);
    expect(json['price'], isNull);
    expect(json['expense_client_id'], 'e1');

    final back = ShoppingItem.fromSync(json)!;
    expect(back.id, 's1');
    expect(back.isPurchased, isTrue);
    expect(back.purchasedAt, DateTime(2026, 4, 2, 11));
    expect(back.createdAt, DateTime(2026, 4, 1, 10));
    expect(back.updatedAt, DateTime.utc(2026, 4, 2, 12));
  });

  test('an unbought item syncs a null purchase time', () {
    final item = ShoppingItem(id: 'a', name: 'b', createdAt: DateTime(2026));
    expect(item.toSyncJson()['purchased_at'], isNull);
    expect(item.syncUpdatedAt, DateTime(2026).toUtc());
  });

  test('readers need id, name and creation time', () {
    expect(ShoppingItem.decode('{"id":"a","name":"b"}'), isNull);
    expect(
      ShoppingItem.decode('{"id":"","name":"b","createdAt":"2026-01-01"}'),
      isNull,
    );
    expect(ShoppingItem.decode('[]'), isNull);
    expect(ShoppingItem.decode('x'), isNull);
    expect(ShoppingItem.fromSync({'client_id': 'a', 'name': 'b'}), isNull);
    expect(
      ShoppingItem.fromSync({
        'client_id': 'a',
        'name': ' ',
        'created_at': '2026-01-01T00:00:00Z',
      }),
      isNull,
    );
  });

  test('copyWith touch and clearPurchase', () {
    final before = DateTime.now().toUtc();
    final renamed = bought.copyWith(name: 'لبن');
    expect(renamed.name, 'لبن');
    expect(renamed.expenseId, 'e1');
    expect(renamed.updatedAt!.isBefore(before), isFalse);

    final quiet = bought.copyWith(name: 'x', touch: false);
    expect(quiet.updatedAt, DateTime.utc(2026, 4, 2, 12));

    final undone = bought.copyWith(clearPurchase: true, isPurchased: true);
    expect(undone.isPurchased, isFalse);
    expect(undone.purchasedAt, isNull);
    expect(undone.expenseId, isNull);
  });
}
