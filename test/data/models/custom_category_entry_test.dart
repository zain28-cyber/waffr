// CustomCategoryEntry: prefs JSON (current and legacy keys), the /sync row
// reader, legacy ids, clamping of palette slots and copyWith.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/custom_category_entry.dart';
import 'package:waffr/data/models/expense_categories.dart';

void main() {
  test('toJson / fromJson round trip', () {
    final entry = CustomCategoryEntry(
      id: 'cat_1',
      label: 'قهوة',
      iconIndex: 3,
      colorIndex: 4,
      updatedAt: DateTime.utc(2026, 2, 3),
    );
    final json = entry.toJson();
    expect(json, {
      'id': 'cat_1',
      'label': 'قهوة',
      'icon': 3,
      'color': 4,
      'updatedAt': '2026-02-03T00:00:00.000Z',
    });

    final back = CustomCategoryEntry.fromJson(json);
    expect(back.id, 'cat_1');
    expect(back.label, 'قهوة');
    expect(back.iconIndex, 3);
    expect(back.colorIndex, 4);
    expect(back.updatedAt, DateTime.utc(2026, 2, 3));
  });

  test('toJson leaves out a missing color', () {
    const entry = CustomCategoryEntry(id: 'a', label: 'b', iconIndex: 0);
    expect(entry.toJson().containsKey('color'), isFalse);
    expect(entry.syncUpdatedAt, DateTime.utc(1970));
  });

  test('fromJson reads older key spellings and string numbers', () {
    final entry = CustomCategoryEntry.fromJson({
      'client_id': ' cat_9 ',
      'label': ' نادي ',
      'icon_index': '5',
      'color_index': '2',
      'updated_at': '2026-01-01T00:00:00Z',
    });
    expect(entry.id, 'cat_9');
    expect(entry.label, 'نادي');
    expect(entry.iconIndex, 5);
    expect(entry.colorIndex, 2);
    expect(entry.updatedAt, DateTime.utc(2026));
  });

  test('fromJson without an id derives a stable legacy id', () {
    final first = CustomCategoryEntry.fromJson({'label': 'هدايا'});
    final second = CustomCategoryEntry.fromJson({'label': 'هدايا'});
    expect(first.id, second.id);
    expect(first.id, CustomCategoryEntry.legacyId('هدايا'));
    expect(first.id, startsWith('cat_'));
    expect(first.iconIndex, 0);
    expect(first.colorIndex, isNull);
    expect(first.updatedAt, isNotNull, reason: 'stamped now');
  });

  test('out-of-range palette slots are clamped', () {
    final entry = CustomCategoryEntry.fromJson({
      'id': 'x',
      'label': 'x',
      'icon': 9999,
      'color': -4,
    });
    expect(entry.iconIndex, customCategoryIconChoices.length - 1);
    expect(entry.colorIndex, 0);

    final bad = CustomCategoryEntry.fromJson({
      'id': 'x',
      'label': 'x',
      'icon': 'abc',
      'color': 'abc',
    });
    expect(bad.iconIndex, 0);
    expect(bad.colorIndex, isNull);
  });

  test('fromSync needs a label and a client id', () {
    expect(CustomCategoryEntry.fromSync({'client_id': 'a'}), isNull);
    expect(CustomCategoryEntry.fromSync({'label': 'a'}), isNull);
    final entry = CustomCategoryEntry.fromSync({
      'client_id': 'a',
      'label': 'b',
      'icon_index': 1,
    })!;
    expect(entry.updatedAt, isNull, reason: 'sync rows are not stamped now');
    expect(entry.colorIndex, isNull);
  });

  test('legacy ids differ per label', () {
    expect(
      CustomCategoryEntry.legacyId('a'),
      isNot(CustomCategoryEntry.legacyId('b')),
    );
    expect(CustomCategoryEntry.legacyId(''), 'cat_0');
  });

  test('copyWith keeps the id and unchanged fields', () {
    const entry = CustomCategoryEntry(
      id: 'a',
      label: 'b',
      iconIndex: 1,
      colorIndex: 2,
    );
    final renamed = entry.copyWith(label: 'c');
    expect(renamed.id, 'a');
    expect(renamed.label, 'c');
    expect(renamed.iconIndex, 1);
    expect(renamed.colorIndex, 2);
  });

  test('toCategory uses the saved icon and color slots', () {
    const entry = CustomCategoryEntry(
      id: 'a',
      label: 'b',
      iconIndex: 2,
      colorIndex: 5,
    );
    final category = entry.toCategory();
    expect(category.label, 'b');
    expect(category.icon, customCategoryIconChoices[2]);
    expect(category.color, customCategoryColors[5]);
    expect(category.darkColor, customCategoryDarkColors[5]);
  });

  test('new ids are unique', () {
    expect({
      for (var i = 0; i < 10; i++) CustomCategoryEntry.newId(),
    }, hasLength(10));
  });
}
