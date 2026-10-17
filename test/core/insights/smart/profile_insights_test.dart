// ProfileInsights: the weighted health score and its parts, health labels,
// the persona, streak, usage-duration and logging-habit cards, and the
// composition of the profile list.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/insights/smart/insight_phrasing.dart';
import 'package:waffr/core/insights/smart/profile_insights.dart';
import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';

import '../../../helpers/ledger_builders.dart';

final DateTime _now = DateTime(2026, 10, 20, 12);

ProfileInsights _rules(SmartFacts facts) =>
    ProfileInsights(facts, InsightPhrasing('ل.س', math.Random(5)));

Map<String, SmartInsight> _run(SmartFacts facts) => {
  for (final item in _rules(facts).all()) item.id: item,
};

void main() {
  test('health labels follow the bands', () {
    expect(healthLabel(100), 'ممتازة');
    expect(healthLabel(80), 'ممتازة');
    expect(healthLabel(79), 'جيدة');
    expect(healthLabel(65), 'جيدة');
    expect(healthLabel(64), 'مقبولة');
    expect(healthLabel(45), 'مقبولة');
    expect(healthLabel(44), 'تحتاج إلى اهتمام');
    expect(healthLabel(0), 'تحتاج إلى اهتمام');
  });

  group('healthScore', () {
    test('an empty ledger scores only the logging part, so 0', () {
      expect(_rules(buildFacts(now: _now)).healthScore(), 0);
    });

    test('a balance without a pace earns a neutral 15 of 25', () {
      // 15 of the 40 possible points (balance 25 + logging 15).
      expect(_rules(buildFacts(now: _now, balance: 100)).healthScore(), 38);
    });

    test('a strong saver who logs daily scores high', () {
      final facts = buildFacts(
        now: _now,
        balance: 5000,
        monthlyIncome: 1000,
        hasRecurringIncome: true,
        expenses: [
          for (var d = 1; d <= 20; d++) expenseAt(10, DateTime(2026, 10, d)),
          for (var d = 1; d <= 20; d++) expenseAt(20, DateTime(2026, 9, d)),
        ],
        transfers: [transferAt(600, DateTime(2026, 10, 2))],
      );
      final score = _rules(facts).healthScore();
      expect(score, greaterThanOrEqualTo(80));
      expect(HealthBand.of(score), HealthBand.excellent);

      final card = _run(facts)['health-score']!;
      expect(card.priority, 100);
      expect(card.tone, InsightTone.positive);
      expect(card.detail, contains('التوفير: 30/30'));
      expect(card.detail, contains('انتظام التسجيل: 15/15'));
      expect(card.detail, contains('اتجاه الصرف: 15/15'));
    });

    test('heavy bills and an empty balance pull the score down', () {
      final facts = buildFacts(
        now: _now,
        balance: 0,
        monthlyIncome: 1000,
        hasRecurringIncome: true,
        expenses: [expenseAt(10, DateTime(2026, 10, 20))],
        obligations: [
          ObligationFact(
            name: 'x',
            amount: 700,
            monthlyEquivalent: 700,
            nextDueAt: DateTime(2026, 11, 1),
          ),
        ],
      );
      final card = _run(facts)['health-score']!;
      expect(card.tone, InsightTone.warning);
      expect(card.detail, contains('الالتزامات: 0/15'));
      expect(card.detail, contains('كفاية الرصيد: 0/25'));
    });
  });

  test(
    'the list starts with the score and adds two report and savings cards',
    () {
      final cards = _rules(
        buildFacts(
          now: _now,
          balance: 100,
          expenses: [expenseAt(10, DateTime(2026, 10, 20))],
        ),
      ).all();
      expect(cards.first.id, 'health-score');
      expect(cards[1].id, 'persona');
    },
  );

  group('persona', () {
    test('a 20% saver is the disciplined saver', () {
      final persona = _run(
        buildFacts(
          now: _now,
          monthlyIncome: 1000,
          expenses: [expenseAt(10, DateTime(2026, 10, 1))],
          transfers: [transferAt(900, DateTime(2026, 9, 1))],
        ),
      )['persona']!;
      expect(
        persona.title,
        anyOf(contains('المدّخر المنضبط'), contains('صاحب الخطة')),
      );
    });

    test('food or fun as the top category is the social one', () {
      final persona = _run(
        buildFacts(
          now: _now,
          expenses: [expenseAt(10, DateTime(2026, 10, 1), category: 'ترفيه')],
        ),
      )['persona']!;
      expect(
        persona.title,
        anyOf(contains('محبّ التجارب'), contains('الاجتماعي')),
      );
      expect(persona.body, contains('الترفيه'));
    });

    test('no expenses means no persona', () {
      expect(_run(buildFacts(now: _now)).containsKey('persona'), isFalse);
    });
  });

  test('streak cards: a week or more is praise, less is a nudge', () {
    expect(_run(buildFacts(now: _now)).containsKey('streak'), isFalse);
    final week = _run(buildFacts(now: _now, streakCount: 9))['streak']!;
    expect(week.tone, InsightTone.positive);
    expect(week.priority, 58);
    final short = _run(buildFacts(now: _now, streakCount: 2))['streak']!;
    expect(short.tone, InsightTone.tip);
    expect(short.priority, 36);
  });

  test('usage duration shows from the seventh day', () {
    expect(
      _run(buildFacts(now: _now, usageStartedAt: DateTime(2026, 10, 15)))
          .containsKey('usage-duration'),
      isFalse,
    );
    final card = _run(
      buildFacts(now: _now, usageStartedAt: DateTime(2026, 10, 1)),
    )['usage-duration']!;
    expect('${card.title} ${card.body}', contains('20 يوماً'));
  });

  test('logging habit: idle for three days, or twenty active days', () {
    final idle = _run(
      buildFacts(now: _now, expenses: [expenseAt(10, DateTime(2026, 10, 15))]),
    )['logging-habit']!;
    expect(idle.action, InsightAction.addExpense);
    expect(idle.priority, 76);

    final steady = _run(
      buildFacts(
        now: _now,
        expenses: [
          for (var d = 0; d < 22; d++)
            expenseAt(1, DateTime(2026, 10, 20).subtract(Duration(days: d))),
        ],
      ),
    )['logging-habit']!;
    expect(steady.tone, InsightTone.positive);
  });
}
