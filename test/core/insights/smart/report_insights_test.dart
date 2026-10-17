// ReportInsights rules: which spending cards appear for which numbers, with
// their tone, priority and action, and largestCategory.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/insights/smart/insight_phrasing.dart';
import 'package:waffr/core/insights/smart/report_insights.dart';
import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/data/models/transaction.dart';

import '../../../helpers/ledger_builders.dart';

// Tuesday 20 October 2026, noon.
final DateTime _now = DateTime(2026, 10, 20, 12);

Map<String, SmartInsight> _run(SmartFacts facts, {int seed = 1}) => {
  for (final item in ReportInsights(
    facts,
    InsightPhrasing('ل.س', math.Random(seed)),
  ).all())
    item.id: item,
};

List<WaffrTransaction> _daily(
  int month,
  double amount, {
  int days = 20,
  String category = 'طعام',
}) => [
  for (var d = 1; d <= days; d++)
    expenseAt(amount, DateTime(2026, month, d, 12), category: category),
];

void main() {
  test('largestCategory picks the biggest total', () {
    expect(largestCategory({}), isNull);
    expect(largestCategory({'a': 1, 'b': 3, 'c': 2})!.key, 'b');
  });

  test('without expenses only the start card shows', () {
    final cards = _run(buildFacts(now: _now));
    expect(cards.keys, ['no-expenses']);
    expect(cards['no-expenses']!.action, InsightAction.addExpense);
    expect(cards['no-expenses']!.priority, 100);
  });

  test('a rising month and a category spike are warnings', () {
    final cards = _run(
      buildFacts(now: _now, expenses: [..._daily(10, 50), ..._daily(9, 25)]),
    );
    final trend = cards['month-trend']!;
    expect(trend.tone, InsightTone.warning);
    expect(trend.priority, 95);
    expect(trend.detail, contains('1,000 ل.س'));
    expect(trend.detail, contains('500 ل.س'));

    final spike = cards['category-spike']!;
    expect(spike.tone, InsightTone.warning);
    expect(spike.action, InsightAction.expenseHistory);
    expect(spike.detail, contains('1,000 ل.س'));
    expect(cards.containsKey('top-category'), isFalse, reason: 'one category');
  });

  test('a falling month and a category drop are positive', () {
    final cards = _run(
      buildFacts(now: _now, expenses: [..._daily(10, 10), ..._daily(9, 25)]),
    );
    expect(cards['month-trend']!.tone, InsightTone.positive);
    expect(cards['month-trend']!.priority, 70);
    expect(cards['category-drop']!.action, InsightAction.manualSave);
  });

  test('a steady month is information', () {
    final cards = _run(
      buildFacts(now: _now, expenses: [..._daily(10, 25), ..._daily(9, 24)]),
    );
    expect(cards['month-trend']!.tone, InsightTone.info);
    expect(cards['month-trend']!.priority, 40);
  });

  test('no month comparison before the 3rd', () {
    final cards = _run(
      buildFacts(
        now: DateTime(2026, 10, 2, 12),
        expenses: [
          expenseAt(50, DateTime(2026, 10, 1)),
          expenseAt(5, DateTime(2026, 9, 1)),
        ],
      ),
    );
    expect(cards.containsKey('month-trend'), isFalse);
  });

  test('one dominant category, a big expense, «أخرى» and small amounts', () {
    final cards = _run(
      buildFacts(
        now: _now,
        expenses: [
          expenseAt(
            600,
            DateTime(2026, 10, 5),
            category: 'ترفيه',
            note: 'حفلة',
          ),
          expenseAt(300, DateTime(2026, 10, 6), category: 'أخرى'),
          ..._daily(10, 10),
        ],
      ),
    );
    expect(cards['top-category']!.tone, InsightTone.warning);
    expect(cards['top-category']!.priority, 72);
    expect(
      cards['top-category']!.detail!.split('\n').first,
      startsWith('ترفيه'),
    );
    expect(cards['largest-expense']!.body, contains('«حفلة»'));
    expect(cards['uncategorized']!.action, InsightAction.expenseHistory);
    expect(cards['small-expenses']!.tone, InsightTone.tip);
    expect(cards.containsKey('no-spend-days'), isFalse);
  });

  test('quiet days, card payments and late nights', () {
    final cards = _run(
      buildFacts(
        now: _now,
        expenses: [
          for (var d = 2; d <= 16; d += 2)
            expenseAt(20, DateTime(2026, 10, d, 23), paymentMethod: 'بطاقة'),
        ],
      ),
    );
    expect(cards['no-spend-days']!.title, isNotEmpty);
    expect(cards['payment-mix']!.tone, InsightTone.tip);
    expect(cards['night-spending']!.tone, InsightTone.tip);
  });

  test('a weekday that costs far more than the rest', () {
    final expenses = [
      for (
        var day = DateTime(2026, 8, 28);
        day.isBefore(_now);
        day = day.add(const Duration(days: 1))
      )
        if (day.weekday == DateTime.friday)
          expenseAt(500, day)
        else if (day.weekday <= DateTime.wednesday)
          expenseAt(10, day),
    ];
    final cards = _run(buildFacts(now: _now, expenses: expenses));
    expect(cards['weekday-peak']!.title, contains('الجمعة'));
  });

  group('balance, income and bills', () {
    final pace = [
      for (var d = 7; d <= 20; d++) expenseAt(100, DateTime(2026, 10, d)),
    ];
    final bill = ObligationFact(
      name: 'إيجار',
      amount: 500,
      monthlyEquivalent: 500,
      nextDueAt: DateTime(2026, 10, 22),
    );

    test('a short runway, a bill above the balance and a heavy share', () {
      final cards = _run(
        buildFacts(
          now: _now,
          expenses: pace,
          balance: 300,
          monthlyIncome: 1000,
          hasRecurringIncome: true,
          obligations: [bill],
        ),
      );
      expect(cards['runway']!.priority, 92);
      expect(cards['runway']!.detail, contains('300 ل.س'));
      expect(cards['obligations-soon']!.priority, 90);
      expect(cards['obligations-soon']!.body, contains('«إيجار»'));
      expect(cards['obligations-share']!.tone, InsightTone.warning);
      expect(cards['obligations-share']!.priority, 75);
      expect(cards['projection']!.tone, InsightTone.warning);
      expect(cards['projection']!.priority, 88);
    });

    test('an empty balance gets the top warning', () {
      final cards = _run(
        buildFacts(
          now: _now,
          expenses: pace,
          balance: 0,
          hasRecurringIncome: true,
        ),
      );
      expect(cards['runway']!.priority, 95);
      expect(cards['runway']!.body, contains('12 يوماً'));
    });

    test('a balance that lasts is good news; light bills are info', () {
      final cards = _run(
        buildFacts(
          now: _now,
          expenses: pace,
          balance: 5000,
          monthlyIncome: 10000,
          hasRecurringIncome: true,
          obligations: [
            ObligationFact(
              name: 'نت',
              amount: 1500,
              monthlyEquivalent: 1500,
              nextDueAt: DateTime(2026, 11, 20),
            ),
          ],
        ),
      );
      expect(cards['runway']!.tone, InsightTone.positive);
      expect(cards['obligations-share']!.tone, InsightTone.info);
      expect(cards.containsKey('obligations-soon'), isFalse);
      expect(cards['projection']!.tone, InsightTone.positive);
    });
  });

  test('no card text leaks placeholders', () {
    final facts = buildFacts(
      now: _now,
      expenses: [
        ..._daily(10, 50),
        ..._daily(9, 25, category: 'تسوق'),
      ],
      balance: 100,
      monthlyIncome: 800,
      hasRecurringIncome: true,
    );
    for (var seed = 0; seed < 20; seed++) {
      for (final card in _run(facts, seed: seed).values) {
        for (final text in [card.title, card.body, card.detail ?? '']) {
          expect(text, isNot(contains('null')));
          expect(text, isNot(contains('NaN')));
          expect(text, isNot(contains(r'$')));
        }
      }
    }
  });
}
