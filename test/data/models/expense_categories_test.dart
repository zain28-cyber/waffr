// Expense category catalog: lookups for built-in, fallback and custom
// labels, palette clamping and slot assignment, and the chart color by theme.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/expense_categories.dart';

void main() {
  tearDown(() => customCategoryLookup = null);

  test('the catalog has unique labels and matching palettes', () {
    final labels = expenseCategories.map((item) => item.label).toList();
    expect(labels.toSet(), hasLength(labels.length));
    expect(labels, isNot(contains(fallbackCategory.label)));
    expect(customCategoryColors, hasLength(customCategoryDarkColors.length));
    expect(paymentMethods.first, 'نقداً');
  });

  test('categoryFor resolves built-ins, the fallback and blanks', () {
    expect(categoryFor('طعام'), same(expenseCategories.first));
    expect(categoryFor('أخرى'), same(fallbackCategory));
    expect(categoryFor(null), same(fallbackCategory));
    expect(categoryFor(''), same(fallbackCategory));
  });

  test('unknown labels use the lookup hook, else a hashed category', () {
    const custom = ExpenseCategory(
      label: 'قهوة',
      icon: Icons.local_cafe_outlined,
      color: Color(0xFF000001),
      darkColor: Color(0xFF000002),
    );
    customCategoryLookup = (label) => label == 'قهوة' ? custom : null;
    expect(categoryFor('قهوة'), same(custom));

    final hashed = categoryFor('شيء');
    expect(hashed.label, 'شيء');
    expect(customCategoryIconChoices, contains(hashed.icon));
    expect(customCategoryColors, contains(hashed.color));
    // Stable for the same label.
    expect(categoryFor('شيء').icon, hashed.icon);
  });

  test('customCategoryNamed keeps saved slots and clamps them', () {
    final named = customCategoryNamed('x', iconIndex: 1, colorIndex: 2);
    expect(named.icon, customCategoryIconChoices[1]);
    expect(named.color, customCategoryColors[2]);
    expect(named.darkColor, customCategoryDarkColors[2]);

    final clamped = customCategoryNamed('x', iconIndex: 999, colorIndex: -1);
    expect(clamped.icon, customCategoryIconChoices.last);
    expect(clamped.color, customCategoryColors.first);
  });

  test('palette index helpers', () {
    expect(clampCustomIconIndex(-5), 0);
    expect(clampCustomIconIndex(3), 3);
    expect(clampCustomColorIndex(100), customCategoryColors.length - 1);

    expect(nextCustomColorIndex(const []), 0);
    expect(nextCustomColorIndex(const [0, 1, 3]), 2);
    final all = List.generate(customCategoryColors.length, (i) => i);
    expect(nextCustomColorIndex(all), 0, reason: 'wraps once all are used');
  });

  testWidgets('chart color follows the theme brightness', (tester) async {
    Future<Color> colorUnder(Brightness brightness) async {
      late Color color;
      await tester.pumpWidget(
        Theme(
          data: ThemeData(brightness: brightness),
          child: Builder(
            builder: (context) {
              color = categoryChartColor(context, 'طعام');
              return const SizedBox();
            },
          ),
        ),
      );
      return color;
    }

    expect(await colorUnder(Brightness.light), expenseCategories.first.color);
    expect(
      await colorUnder(Brightness.dark),
      expenseCategories.first.darkColor,
    );
  });
}
