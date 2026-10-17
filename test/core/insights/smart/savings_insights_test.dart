// SavingsInsights rules (goals near, late, behind, on track and stalled;
// saving rate; withdrawals; habits; emergency fund; shopping list) and the
// suggested monthly saving with its rounding.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/insights/smart/insight_phrasing.dart';
import 'package:waffr/core/insights/smart/savings_insights.dart';
import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/data/models/transaction.dart';

import '../../../helpers/ledger_builders.dart';

final DateTime _now = DateTime(2026, 10, 20, 12);

SavingsInsights _rules(SmartFacts facts) =>
    SavingsInsights(facts, InsightPhrasing('ل.س', math.Random(3)));

Map<String, SmartInsight> _run(SmartFacts facts) => {
  for (final item in _rules(facts).all()) item.id: item,
};

GoalFact _goal(
  String id, {
  double target = 1000,
  double saved = 0,
  DateTime? created,
  double months = 6,
}) => GoalFact(
  id: id,
  name: 'هدف $id',
  target: target,
  saved: saved,
  createdAt: created ?? DateTime(2026, 10, 1),
  plannedMonths: months,
);

void main() {
  test('no goal suggests creating one', () {
    final cards = _run(buildFacts(now: _now));
    expect(cards['no-goals']!.action, InsightAction.createGoal);
    expect(cards['no-goals']!.priority, 80);
  });

  test('each goal gets its state card', () {
    final cards = _run(
      buildFacts(
        now: _now,
        goals: [
          _goal('near', saved: 850),
          _goal('late', created: DateTime(2026, 1, 1), months: 1),
          _goal('behind'),
          _goal('done', saved: 1000),
        ],
      ),
    );
    expect(cards['goal-near-near']!.tone, InsightTone.positive);
    expect(cards['goal-near-near']!.detail, contains('150 ل.س'));
    expect(cards['goal-late-late']!.tone, InsightTone.warning);
    expect(cards['goal-behind-behind']!.detail, contains('المطلوب شهرياً'));
    expect(cards.keys.where((k) => k.contains('done')), isEmpty);
  });

  test('a goal funded at a good pace is on track', () {
    final cards = _run(
      buildFacts(
        now: _now,
        goals: [_goal('g', saved: 200)],
        transfers: [transferAt(600, DateTime(2026, 10, 10), goalId: 'g')],
      ),
    );
    expect(cards['goal-ontrack-g']!.tone, InsightTone.positive);
    expect(cards.containsKey('goal-stalled-g'), isFalse);
  });

  test('an old goal without recent saving is stalled', () {
    final cards = _run(
      buildFacts(
        now: _now,
        goals: [_goal('g', created: DateTime(2026, 8, 1), months: 12)],
        transfers: [transferAt(10, DateTime(2026, 8, 5), goalId: 'g')],
      ),
    );
    expect(cards['goal-stalled-g']!.action, InsightAction.manualSave);
  });

  test('saving rate against the 20% rule', () {
    SmartInsight rate(double saved) => _run(
      buildFacts(
        now: _now,
        monthlyIncome: 1000,
        transfers: [transferAt(saved, DateTime(2026, 10, 15))],
      ),
    )['savings-rate']!;

    expect(rate(300).tone, InsightTone.positive);
    expect(rate(20).tone, InsightTone.tip);
    expect(rate(20).action, InsightAction.manualSave);
    expect(rate(100).tone, InsightTone.info);
    expect(_run(buildFacts(now: _now)).containsKey('savings-rate'), isFalse);
  });

  group('suggestedMonthlySaving', () {
    test('needs a known income with money left over', () {
      expect(_rules(buildFacts(now: _now)).suggestedMonthlySaving(), isNull);
      expect(
        _rules(
          buildFacts(
            now: _now,
            monthlyIncome: 100,
            expenses: [expenseAt(500, DateTime(2026, 9, 1))],
          ),
        ).suggestedMonthlySaving(),
        isNull,
      );
    });

    test(
      'takes the smaller of 70% of the spare and 20% of income, rounded',
      () {
        double? suggest(double income, double spentPerMonth) => _rules(
          buildFacts(
            now: _now,
            monthlyIncome: income,
            expenses: [
              if (spentPerMonth > 0) ...[
                expenseAt(spentPerMonth, DateTime(2026, 9, 1)),
                expenseAt(spentPerMonth, DateTime(2026, 8, 1)),
                expenseAt(spentPerMonth, DateTime(2026, 7, 1)),
              ],
            ],
          ),
        ).suggestedMonthlySaving();

        expect(suggest(1000, 500), 200);
        expect(suggest(10000, 9000), 700);
        expect(suggest(3333, 0), 660);
        expect(suggest(12345, 0), 2400);
        expect(suggest(80, 0), 16);
      },
    );

    test('the suggestion card points to a goal when there is none', () {
      final cards = _run(buildFacts(now: _now, monthlyIncome: 1000));
      expect(cards['saving-suggestion']!.action, InsightAction.createGoal);
      final withGoal = _run(
        buildFacts(now: _now, monthlyIncome: 1000, goals: [_goal('g')]),
      );
      expect(withGoal['saving-suggestion']!.action, InsightAction.manualSave);
    });
  });

  test('habits: withdrawals, leftovers, completed goals, shopping', () {
    final cards = _run(
      buildFacts(
        now: _now,
        transfers: [
          transferAt(10, DateTime(2026, 10, 1), out: true),
          transferAt(10, DateTime(2026, 10, 5), out: true),
          transferAt(
            50,
            DateTime(2026, 9, 1),
            kind: SavingsTransferKind.periodLeftover,
          ),
        ],
        completedGoals: 2,
        pendingShopping: 3,
      ),
    );
    expect(cards['withdrawals']!.tone, InsightTone.warning);
    expect(cards['withdrawals']!.priority, 72);
    expect(cards['leftover-habit']!.tone, InsightTone.positive);
    expect(cards['completed-goals']!.action, InsightAction.createGoal);
    expect(cards['shopping-list']!.action, InsightAction.shoppingList);
  });

  test('emergency fund: three months of spending is the target', () {
    final spending = [
      expenseAt(500, DateTime(2026, 9, 1)),
      expenseAt(500, DateTime(2026, 8, 1)),
    ];
    final strong = _run(
      buildFacts(now: _now, expenses: spending, savingsBalance: 2000),
    );
    expect(strong['emergency-fund']!.tone, InsightTone.positive);

    final weak = _run(
      buildFacts(now: _now, expenses: spending, savingsBalance: 100),
    );
    expect(weak['emergency-fund']!.tone, InsightTone.tip);
    expect(weak['emergency-fund']!.body, contains('1,500 ل.س'));
  });
}
