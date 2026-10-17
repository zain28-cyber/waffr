// CategoryStore: name validation, adding/renaming/removing custom
// categories (archive keeps old looks, tombstones on delete), hiding
// built-ins, colors, legacy prefs migration and the remote sync merge.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/data/stores/category_store.dart';

import '../../helpers/store_harness.dart';

void main() {
  final store = CategoryStore.instance;
  late SharedPreferences prefs;

  setUp(() async {
    prefs = await setUpStores();
    await store.ensureLoaded();
  });

  test('starts with every built-in selectable', () {
    expect(store.customCategories, isEmpty);
    expect(store.selectableCategories, expenseCategories);
    expect(store.defaultLabel, expenseCategories.first.label);
    expect(store.isBuiltIn('طعام'), isTrue);
    expect(store.isCustom('طعام'), isFalse);
  });

  test('registers itself as the chart lookup', () async {
    await store.addCustom('قهوة', iconIndex: 4);
    expect(customCategoryLookup, isNotNull);
    expect(categoryFor('قهوة').icon, customCategoryIconChoices[4]);
  });

  group('validateName', () {
    test('rejects blanks, reserved names and duplicates', () async {
      expect(store.validateName('  '), 'أدخل اسماً للتصنيف');
      expect(store.validateName(customCategoryActionLabel), 'هذا الاسم محجوز');
      expect(store.validateName('أخرى'), 'هذا الاسم محجوز');
      expect(store.validateName(' طعام '), 'هذا التصنيف موجود مسبقاً');
      expect(store.validateName('جديد'), isNull);

      await store.addCustom('قهوة');
      expect(store.validateName('قهوة'), 'هذا التصنيف موجود مسبقاً');
      expect(store.validateName('قهوة', ignoring: 'قهوة'), isNull);
    });

    test('a rename may not take a hidden built-in name', () async {
      await store.addCustom('قهوة');
      await store.removeCategory('صحة');
      expect(store.validateName('صحة'), isNull, reason: 'add brings it back');
      expect(
        store.validateName('صحة', ignoring: 'قهوة'),
        'هذا التصنيف موجود مسبقاً',
      );
    });
  });

  group('custom categories', () {
    test('add gives each category its own color slot', () async {
      expect(await store.addCustom('  قهوة '), 'قهوة');
      expect(await store.addCustom('نادي', iconIndex: 999), 'نادي');
      expect(await store.addCustom('قهوة'), isNull);

      expect(store.entries.map((e) => e.colorIndex), [0, 1]);
      expect(store.iconIndexOf('نادي'), customCategoryIconChoices.length - 1);
      expect(store.iconIndexOf('missing'), 0);
      expect(store.selectableCategories.last.label, 'نادي');
      expect(store.isCustom('قهوة'), isTrue);
    });

    test('rename keeps the id and archives the old look', () async {
      await store.addCustom('قهوة', iconIndex: 2);
      final id = store.entries.single.id;
      final oldIcon = categoryFor('قهوة').icon;

      expect(await store.renameCustom('missing', 'x'), isNull);
      expect(await store.renameCustom('قهوة', 'طعام'), isNull);
      expect(await store.renameCustom('قهوة', 'مقهى', iconIndex: 5), 'مقهى');

      expect(store.entries.single.id, id);
      expect(store.entries.single.iconIndex, 5);
      expect(store.isSelectable('قهوة'), isFalse);
      expect(categoryFor('قهوة').icon, oldIcon, reason: 'archived');
    });

    test(
      'remove logs a tombstone and keeps history looking the same',
      () async {
        await store.addCustom('قهوة', iconIndex: 3);
        final id = store.entries.single.id;

        expect(await store.removeCustom('missing'), isFalse);
        expect(await store.removeCustom('قهوة'), isTrue);
        expect(store.entries, isEmpty);
        expect(
          SyncTombstones.instance.find(SyncCollection.expenseCategories, id),
          isNotNull,
        );
        expect(store.findCustom('قهوة')?.icon, customCategoryIconChoices[3]);
      },
    );
  });

  group('built-ins', () {
    test('hiding moves the default and can be undone by adding', () async {
      expect(await store.removeCategory('طعام'), isTrue);
      expect(await store.removeCategory('طعام'), isFalse);
      expect(await store.removeCategory('غير موجود'), isFalse);
      expect(store.defaultLabel, expenseCategories[1].label);
      expect(store.hiddenBuiltIns, ['طعام']);

      expect(await store.addCustom('طعام'), 'طعام');
      expect(store.hiddenBuiltIns, isEmpty);
      expect(store.entries, isEmpty, reason: 'no custom copy is created');
    });

    test('hidden labels come back in catalog order and persist', () async {
      await store.removeCategory('تعليم');
      await store.removeCategory('مواصلات');
      expect(store.hiddenBuiltIns, ['مواصلات', 'تعليم']);

      resetStoreCaches();
      await store.ensureLoaded();
      expect(store.hiddenBuiltIns, ['مواصلات', 'تعليم']);
    });

    test('hiding all built-ins leaves the fallback as default', () async {
      for (final item in expenseCategories) {
        await store.removeCategory(item.label);
      }
      expect(store.selectableCategories, isEmpty);
      expect(store.defaultLabel, 'أخرى');
    });

    test('remote hidden lists ignore unknown labels and non-lists', () async {
      await store.applyRemoteHidden('not a list');
      await store.applyRemoteHidden(['صحة', 'Netflix']);
      expect(store.hiddenBuiltIns, ['صحة']);
    });
  });

  group('persistence', () {
    test('custom categories survive a reload with their colors', () async {
      await store.addCustom('قهوة', iconIndex: 1);
      await store.addCustom('نادي', iconIndex: 2);
      resetStoreCaches();
      await store.ensureLoaded();
      expect(store.entries.map((e) => e.label), ['قهوة', 'نادي']);
      expect(store.entries.map((e) => e.colorIndex), [0, 1]);
      expect(store.entries.map((e) => e.iconIndex), [1, 2]);
    });

    test('the oldest string-list format is migrated to v2 JSON', () async {
      await prefs.setStringList(CategoryStore.itemsKey, ['قهوة', ' ', 'نادي']);
      resetStoreCaches();
      await store.ensureLoaded();

      expect(store.entries.map((e) => e.label), ['قهوة', 'نادي']);
      expect(store.entries.first.id, CustomCategoryEntry.legacyId('قهوة'));
      expect(store.entries.map((e) => e.colorIndex), [0, 1]);
      expect(prefs.getString(CategoryStore.itemsJsonKey), contains('قهوة'));
    });

    test('v2 JSON without ids gets legacy ids written back', () async {
      await prefs.setString(
        CategoryStore.itemsJsonKey,
        jsonEncode([
          {'label': 'قهوة', 'icon': 3},
          {'label': ''},
        ]),
      );
      resetStoreCaches();
      await store.ensureLoaded();
      expect(store.entries.single.label, 'قهوة');
      expect(prefs.getString(CategoryStore.itemsJsonKey), contains('"id"'));
    });

    test('corrupt JSON loads as empty', () async {
      await prefs.setString(CategoryStore.itemsJsonKey, '{oops');
      resetStoreCaches();
      await store.ensureLoaded();
      expect(store.entries, isEmpty);
    });
  });

  group('applyRemoteSync', () {
    Map<String, dynamic> row(String id, String label, {String? updated}) => {
      'client_id': id,
      'label': label,
      'icon_index': 1,
      'updated_at': updated ?? '2026-01-01T00:00:00Z',
    };

    test('adds server categories and gives them free colors', () async {
      await store.applyRemoteSync(
        upserts: [row('c1', 'قهوة'), row('c2', 'نادي')],
        deletes: const [],
      );
      expect(store.entries.map((e) => e.label), ['قهوة', 'نادي']);
      expect(store.entries.map((e) => e.colorIndex), [0, 1]);
    });

    test(
      'a newer rename keeps the local color and archives the old name',
      () async {
        await store.applyRemoteSync(
          upserts: [row('c1', 'قهوة')],
          deletes: const [],
        );
        final color = store.entries.single.colorIndex;
        await store.applyRemoteSync(
          upserts: [row('c1', 'مقهى', updated: '2026-02-01T00:00:00Z')],
          deletes: const [],
        );
        expect(store.entries.single.label, 'مقهى');
        expect(store.entries.single.colorIndex, color);
        expect(store.findCustom('قهوة'), isNotNull);
      },
    );

    test('server deletes remove categories', () async {
      await store.applyRemoteSync(
        upserts: [row('c1', 'قهوة')],
        deletes: const [],
      );
      await store.applyRemoteSync(
        upserts: const [],
        deletes: [SyncTombstone(clientId: 'c1', deletedAt: DateTime.utc(2027))],
      );
      expect(store.entries, isEmpty);
      expect(store.findCustom('قهوة'), isNotNull, reason: 'archived');
    });

    test('invalid rows are ignored', () async {
      await store.applyRemoteSync(
        upserts: [
          {'client_id': 'x'},
          {'label': 'y'},
        ],
        deletes: const [],
      );
      expect(store.entries, isEmpty);
    });
  });
}
