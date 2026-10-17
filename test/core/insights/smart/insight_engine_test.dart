// InsightEngine end to end: findings per scope, ranking and limits, the
// closing tip, health score and bands, and seeded wording.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/insights/smart/insight_engine.dart';
import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/data/models/transaction.dart';

final DateTime _now = DateTime(2026, 10, 20, 12);

int _ids = 0;

WaffrTransaction _expense(
  double amount,
  DateTime date, {
  String category = 'طعام',
  String? payment,
}) => WaffrTransaction(
  id: 'e${_ids++}',
  type: TransactionType.expense,
  amount: amount,
  dateTime: date,
  category: category,
  paymentMethod: payment,
);

WaffrTransaction _transfer(
  double amount,
  DateTime date, {
  bool out = false,
  String? goalId,
}) => WaffrTransaction(
  id: 't${_ids++}',
  type: out ? TransactionType.savingsOut : TransactionType.savingsIn,
  amount: amount,
  dateTime: date,
  goalId: goalId,
);

SmartFacts _facts({
  DateTime? now,
  List<WaffrTransaction> expenses = const [],
  List<WaffrTransaction> transfers = const [],
  double balance = 500,
  double? income = 1000,
  bool recurringIncome = true,
  double savingsBalance = 0,
  List<GoalFact> goals = const [],
  List<ObligationFact> obligations = const [],
  int streak = 1,
}) {
  return SmartFacts(
    now: now ?? _now,
    currencySymbol: 'ل.س',
    expenses: expenses,
    incomes: const [],
    savingsTransfers: transfers,
    balance: balance,
    monthlyIncome: income,
    incomeFrequency: recurringIncome
        ? RecurringFrequency.monthly
        : RecurringFrequency.none,
    hasRecurringIncome: recurringIncome,
    savingsBalance: savingsBalance,
    goals: goals,
    completedGoals: 0,
    obligations: obligations,
    pendingShopping: 0,
    streakCount: streak,
    usageStartedAt: null,
  );
}

Set<String> _ids_(SmartReport report) =>
    report.insights.map((item) => item.id).toSet();

void main() {
  test('wallet smiles at 20 percent saving even when expenses are four times larger', () {
    final now = DateTime(2026, 10, 31, 12);
    final facts = _facts(
      now: now,
      income: 1000,
      balance: 0,
      savingsBalance: 200,
      expenses: [
        for (var day = 1; day <= 31; day++)
          _expense(800 / 31, DateTime(2026, 10, day)),
      ],
      transfers: [_transfer(200, DateTime(2026, 10, 1))],
    );
    expect(facts.monthSpent, greaterThan(facts.savedLast30));
    final band = HealthBand.of(InsightEngine(facts).healthScore());
    expect(band, isIn([HealthBand.good, HealthBand.excellent]));
  });

  test(
    '10 percent saving can smile when the remaining balance covers the month',
    () {
      final facts = _facts(
        income: 1000,
        balance: 300,
        savingsBalance: 100,
        expenses: [
          for (var day = 1; day <= 20; day++)
            _expense(30, DateTime(2026, 10, day)),
        ],
        transfers: [_transfer(100, DateTime(2026, 10, 1))],
      );
      expect(facts.monthSpent, greaterThan(facts.savedLast30));
      expect(
        HealthBand.of(InsightEngine(facts).healthScore()),
        isIn([HealthBand.good, HealthBand.excellent]),
      );
    },
  );

  test(
    'health score uses actual savings history instead of three empty months',
    () {
      final facts = _facts(
        income: 1000,
        recurringIncome: false,
        balance: 500,
        transfers: [_transfer(200, DateTime(2026, 10, 1))],
        expenses: [
          for (var day = 1; day <= 15; day++)
            _expense(20, DateTime(2026, 10, day)),
        ],
      );
      expect(facts.averageMonthlySaving, 200);
      expect(InsightEngine(facts).healthScore(), greaterThanOrEqualTo(80));
    },
  );

  test(
    'withdrawals lower the wallet score instead of counting gross saving',
    () {
      final expenses = [
        for (var day = 1; day <= 20; day++)
          _expense(30, DateTime(2026, 10, day)),
      ];
      final saved = [_transfer(200, DateTime(2026, 10, 1))];
      final healthy = InsightEngine(
        _facts(expenses: expenses, transfers: saved),
      );
      final withdrawn = InsightEngine(
        _facts(
          expenses: expenses,
          transfers: [
            ...saved,
            _transfer(200, DateTime(2026, 10, 2), out: true),
          ],
        ),
      );
      expect(withdrawn.healthScore(), lessThan(healthy.healthScore()));
    },
  );

  test('no expenses asks the user to start logging', () {
    final report = InsightEngine(
      _facts(),
      seed: 1,
    ).analyze(InsightScope.reports);

    expect(_ids_(report), contains('no-expenses'));
    expect(report.insights.first.action, InsightAction.addExpense);
  });

  test('month-over-month increase is a warning with the real numbers', () {
    final facts = _facts(
      expenses: [
        for (var day = 1; day <= 20; day++)
          _expense(30, DateTime(2026, 10, day, 10)),
        for (var day = 1; day <= 20; day++)
          _expense(15, DateTime(2026, 9, day, 10)),
      ],
    );

    final report = InsightEngine(facts, seed: 3).analyze(InsightScope.reports);
    final trend = report.insights.firstWhere(
      (item) => item.id == 'month-trend',
    );

    expect(trend.tone, InsightTone.warning);
    expect(trend.detail, contains('600'));
    expect(trend.detail, contains('300'));
  });

  test('a category spike is reported with its name', () {
    final facts = _facts(
      expenses: [
        for (var day = 1; day <= 10; day++)
          _expense(100, DateTime(2026, 10, day), category: 'ترفيه'),
        for (var day = 1; day <= 10; day++)
          _expense(20, DateTime(2026, 9, day), category: 'ترفيه'),
        _expense(50, DateTime(2026, 10, 2), category: 'طعام'),
      ],
    );

    final report = InsightEngine(facts, seed: 2).analyze(InsightScope.reports);
    final spike = report.insights.firstWhere(
      (item) => item.id == 'category-spike',
    );

    expect(spike.title + spike.body, contains('ترفيه'));
  });

  test('runway warns when the balance runs out before income', () {
    // 100 a day for two weeks, 300 left, income in 12 days.
    final facts = _facts(
      balance: 300,
      expenses: [
        for (var day = 7; day <= 20; day++)
          _expense(100, DateTime(2026, 10, day)),
      ],
    );

    final report = InsightEngine(facts, seed: 5).analyze(InsightScope.reports);
    final runway = report.insights.firstWhere((item) => item.id == 'runway');

    expect(runway.tone, InsightTone.warning);
    expect(facts.daysUntilIncome, 12);
  });

  test('savings scope suggests a goal when there is none', () {
    final report = InsightEngine(
      _facts(),
      seed: 4,
    ).analyze(InsightScope.savings);
    final noGoals = report.insights.firstWhere((item) => item.id == 'no-goals');

    expect(noGoals.action, InsightAction.createGoal);
  });

  test('a goal behind schedule asks for the monthly amount needed', () {
    final goal = GoalFact(
      id: 'g1',
      name: 'سفر',
      target: 1200,
      saved: 100,
      createdAt: DateTime(2026, 9, 20),
      plannedMonths: 3,
    );
    final report = InsightEngine(
      _facts(
        goals: [goal],
        transfers: [_transfer(100, DateTime(2026, 9, 25), goalId: 'g1')],
      ),
      seed: 9,
    ).analyze(InsightScope.savings);

    expect(_ids_(report), contains('goal-behind-g1'));
  });

  test('frequent withdrawals are flagged', () {
    final report = InsightEngine(
      _facts(
        transfers: [
          _transfer(50, DateTime(2026, 10, 5), out: true),
          _transfer(50, DateTime(2026, 10, 12), out: true),
        ],
      ),
      seed: 1,
    ).analyze(InsightScope.savings);

    expect(_ids_(report), contains('withdrawals'));
  });

  test('saving suggestion stays within income minus spending', () {
    final facts = _facts(
      expenses: [
        for (var month = 7; month <= 9; month++)
          _expense(600, DateTime(2026, month, 10)),
      ],
    );
    final amount = InsightEngine(facts).suggestedMonthlySaving();

    expect(amount, isNotNull);
    expect(amount!, lessThanOrEqualTo(200)); // 20% of 1000
    expect(amount, greaterThan(0));
  });

  test('profile scope leads with a 0-100 health score', () {
    final facts = _facts(
      streak: 9,
      expenses: [
        for (var day = 1; day <= 20; day++)
          _expense(20, DateTime(2026, 10, day)),
      ],
    );
    final report = InsightEngine(facts, seed: 1).analyze(InsightScope.profile);

    expect(report.healthScore, inInclusiveRange(0, 100));
    expect(report.insights.first.id, 'health-score');
    expect(_ids_(report), contains('streak'));
  });

  test('every report ends with a tip', () {
    for (final scope in InsightScope.values) {
      final report = InsightEngine(_facts(), seed: 7).analyze(scope);
      expect(report.insights.last.id, 'tip');
    }
  });

  test('different seeds word the same findings differently', () {
    final facts = _facts(
      expenses: [
        for (var day = 1; day <= 20; day++)
          _expense(30, DateTime(2026, 10, day, 10)),
        for (var day = 1; day <= 20; day++)
          _expense(15, DateTime(2026, 9, day, 10)),
      ],
    );

    final texts = {
      for (var seed = 0; seed < 12; seed++)
        InsightEngine(facts, seed: seed)
            .analyze(InsightScope.reports)
            .insights
            .map((item) => '${item.title}|${item.body}')
            .join('\n'),
    };
    final findings = {
      for (var seed = 0; seed < 12; seed++)
        (_ids_(
          InsightEngine(facts, seed: seed).analyze(InsightScope.reports),
        ).difference({'tip'}).toList()..sort()).join(','),
    };

    expect(texts.length, greaterThan(5));
    expect(findings.length, 1);
  });

  test('health bands follow the score labels', () {
    expect(HealthBand.of(100), HealthBand.excellent);
    expect(HealthBand.of(80), HealthBand.excellent);
    expect(HealthBand.of(79), HealthBand.good);
    expect(HealthBand.of(65), HealthBand.good);
    expect(HealthBand.of(64), HealthBand.fair);
    expect(HealthBand.of(45), HealthBand.fair);
    expect(HealthBand.of(44), HealthBand.low);
    expect(HealthBand.of(0), HealthBand.low);
  });
}
