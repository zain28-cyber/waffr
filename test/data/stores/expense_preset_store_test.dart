// ExpensePresetStore (dedupe, delete with tombstone, reload, remote merge)
// plus CategoryStore hide/restore and recurring source-id helpers that the
// expense sheet relies on.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/data/models/expense_preset.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/stores/expense_preset_store.dart';

ExpensePreset _preset({String id = 'p1', String? note = 'خبز'}) {
  return ExpensePreset(
    id: id,
    amount: 1500,
    multiplier: 2,
    currencyCode: 'SYP',
    category: 'طعام',
    paymentMethod: 'نقداً',
    note: note,
    recurring: true,
    unit: RecurringUnit.week,
    intervalCount: 2,
    createdAt: DateTime(2026, 10, 1, 9),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.instance;
    await prefs.clear();
    ExpensePresetStore.instance.resetCache();
    CategoryStore.instance.resetCache();
  });

  test('a preset keeps every detail through prefs and sync', () {
    final preset = _preset();
    final stored = ExpensePreset.decode(preset.encode())!;
    final synced = ExpensePreset.fromSync(preset.toSyncJson())!;
    for (final copy in [stored, synced]) {
      expect(copy.id, 'p1');
      expect(copy.total, 3000);
      expect(copy.sameDetailsAs(preset), isTrue);
      expect(copy.unit, RecurringUnit.week);
      expect(copy.intervalCount, 2);
    }
    expect(ExpensePreset.fromSync({'client_id': 'x', 'amount': '0'}), isNull);
  });

  test('saving the same expense twice keeps one preset', () async {
    final store = ExpensePresetStore.instance;
    await store.add(_preset());
    await store.add(_preset(id: 'p2'));
    expect(store.items, hasLength(1));

    await store.add(_preset(id: 'p3', note: 'حليب'));
    expect(store.items, hasLength(2));

    expect(await store.remove('p3'), isTrue);
    expect(
      SyncTombstones.instance
          .of(SyncCollection.expensePresets)
          .map((item) => item.clientId),
      contains('p3'),
    );

    store.resetCache();
    await store.ensureLoaded();
    expect(store.items.single.id, 'p1');
  });

  test('built-in categories can be removed and history keeps them', () async {
    final store = CategoryStore.instance;
    await store.ensureLoaded();
    final food = expenseCategories.first;

    expect(await store.removeCategory(food.label), isTrue);
    expect(store.isSelectable(food.label), isFalse);
    expect(store.hiddenBuiltIns, [food.label]);
    expect(store.defaultLabel, isNot(food.label));
    // Old expenses still resolve the built-in label, icon and color.
    expect(categoryFor(food.label).icon, food.icon);

    store.resetCache();
    await store.ensureLoaded();
    expect(store.isSelectable(food.label), isFalse);

    // Adding it again by name restores the built-in.
    expect(await store.addCustom(food.label), food.label);
    expect(store.isSelectable(food.label), isTrue);
    expect(store.isCustom(food.label), isFalse);
  });

  test('a removed custom category keeps its icon for old expenses', () async {
    final store = CategoryStore.instance;
    await store.addCustom('قهوة', iconIndex: 2);
    final icon = categoryFor('قهوة').icon;
    expect(icon, customCategoryIconChoices[2]);

    expect(await store.removeCategory('قهوة'), isTrue);
    expect(store.isSelectable('قهوة'), isFalse);
    expect(categoryFor('قهوة').icon, icon);

    store.resetCache();
    await store.ensureLoaded();
    expect(categoryFor('قهوة').icon, icon);
  });

  test('remote hidden list replaces the local one', () async {
    final store = CategoryStore.instance;
    await store.applyRemoteHidden(['تعليم', 'غير موجود']);
    expect(store.hiddenBuiltIns, ['تعليم']);
    await store.applyRemoteHidden(const []);
    expect(store.hiddenBuiltIns, isEmpty);
  });

  test('recurring source ids map back to their schedule', () {
    expect(
      RecurringExpense.idFromSource('recurring:r123_4:202610080900'),
      'r123_4',
    );
    expect(RecurringExpense.idFromSource('shopping:item'), isNull);
    expect(RecurringExpense.isRecurringSource(null), isFalse);
  });

  test('applyRemoteSync adds newer presets and applies deletes', () async {
    final store = ExpensePresetStore.instance;
    await store.applyRemoteSync(
      upserts: [
        _preset(id: 'r1').toSyncJson(),
        {'client_id': 'bad'},
      ],
      deletes: const [],
    );
    expect(store.items.single.id, 'r1');

    await store.applyRemoteSync(
      upserts: const [],
      deletes: [SyncTombstone(clientId: 'r1', deletedAt: DateTime.utc(2030))],
    );
    expect(store.items, isEmpty);
    expect(await store.remove('r1'), isFalse);
  });

  test('presets are listed newest first', () async {
    final store = ExpensePresetStore.instance;
    await store.add(
      ExpensePreset(
        id: 'old',
        amount: 1,
        category: 'طعام',
        paymentMethod: 'نقداً',
        createdAt: DateTime(2020),
      ),
    );
    await store.add(_preset());
    store.resetCache();
    await store.ensureLoaded();
    expect(store.items.map((p) => p.id), ['p1', 'old']);
  });
}
