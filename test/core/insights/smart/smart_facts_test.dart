// SmartFacts derived figures: calendar helpers, month/week spans compared
// like for like, recent pace, projection, runway, days to income, savings
// history, logging habits and the effective monthly income; plus GoalFact.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/data/models/transaction.dart';

import '../../../helpers/ledger_builders.dart';

void main() {
  // Tuesday 20 October 2026, noon.
  final now = DateTime(2026, 10, 20, 12);

  test('calendar helpers', () {
    final facts = buildFacts(now: now);
    expect(facts.today, DateTime(2026, 10, 20));
    expect(facts.monthStart, DateTime(2026, 10));
    expect(facts.daysInMonth, 31);
    expect(facts.dayOfMonth, 20);
    expect(facts.daysLeftInMonth, 11);
    expect(facts.weekStart, DateTime(2026, 10, 17));
    expect(facts.prevMonthStart, DateTime(2026, 9));
    expect(facts.prevMonthSameDay, DateTime(2026, 9, 21));
    expect(facts.hasExpenses, isFalse);
  });

  test('the previous span is clamped to a shorter month', () {
    final facts = buildFacts(now: DateTime(2026, 3, 31));
    expect(facts.prevMonthSameDay, DateTime(2026, 3, 1));
  });

  test('spending windows, categories and like-for-like spans', () {
    final facts = buildFacts(
      now: now,
      expenses: [
        expenseAt(100, DateTime(2026, 10, 1)),
        expenseAt(50, DateTime(2026, 10, 20, 9), category: 'صحة'),
        expenseAt(70, DateTime(2026, 10, 18)),
        expenseAt(30, DateTime(2026, 9, 20)),
        expenseAt(999, DateTime(2026, 9, 25)),
        expenseAt(40, DateTime(2026, 10, 12)),
        WaffrTransaction(
          id: 'nocat',
          type: TransactionType.expense,
          amount: 5,
          dateTime: DateTime(2026, 10, 2),
        ),
      ],
    );

    expect(facts.monthSpent, 265);
    expect(facts.prevMonthSpentSameSpan, 30, reason: 'Sep 25 is past the span');
    expect(facts.monthCategories, {'طعام': 210, 'صحة': 50, 'أخرى': 5});
    expect(facts.prevMonthCategories, {'طعام': 30});
    expect(facts.weekSpent, 120);
    expect(facts.prevWeekSpentSameSpan, 40);
    expect(facts.spentBetween(DateTime(2026, 9), DateTime(2026, 10)), 1029);
    expect(
      facts.expensesBetween(DateTime(2026, 10, 18), DateTime(2026, 10, 19)),
      hasLength(1),
    );
    expect(facts.dailyAverageThisMonth, 265 / 20);
    expect(facts.lastExpenseAt, DateTime(2026, 10, 20, 9));
  });

  test('recent pace starts at the first expense when younger than 14 days', () {
    final facts = buildFacts(
      now: now,
      balance: 300,
      expenses: [
        expenseAt(60, DateTime(2026, 10, 16, 18)),
        expenseAt(40, DateTime(2026, 10, 20)),
      ],
    );
    // 16th to 20th inclusive is five days.
    expect(facts.dailyAverageRecent, 20);
    expect(facts.projectedMonthSpend, 100 + 20 * 11);
    expect(facts.runwayDays, 15);
  });

  test('recent pace uses the last 14 days for longer histories', () {
    final facts = buildFacts(
      now: now,
      expenses: [
        expenseAt(1000, DateTime(2026, 9, 1)),
        expenseAt(140, DateTime(2026, 10, 10)),
      ],
    );
    expect(facts.dailyAverageRecent, 10);
  });

  test('no spending means no runway', () {
    final facts = buildFacts(now: now, balance: 100);
    expect(facts.dailyAverageRecent, 0);
    expect(facts.runwayDays, isNull);
  });

  test('days until income need a recurring income', () {
    expect(buildFacts(now: now).daysUntilIncome, isNull);
    expect(
      buildFacts(now: now, hasRecurringIncome: true).daysUntilIncome,
      12,
      reason: 'monthly: 1 November',
    );
    expect(
      buildFacts(
        now: now,
        hasRecurringIncome: true,
        incomeFrequency: RecurringFrequency.weekly,
      ).daysUntilIncome,
      4,
      reason: 'weekly: Saturday 24 October',
    );
    expect(
      buildFacts(
        now: now,
        hasRecurringIncome: true,
        incomeFrequency: RecurringFrequency.none,
      ).daysUntilIncome,
      isNull,
    );
  });

  test('obligations add up their monthly cost', () {
    final facts = buildFacts(
      now: now,
      obligations: [
        ObligationFact(
          name: 'a',
          amount: 1,
          monthlyEquivalent: 30,
          nextDueAt: now,
        ),
        ObligationFact(
          name: 'b',
          amount: 1,
          monthlyEquivalent: 12.5,
          nextDueAt: now,
        ),
      ],
    );
    expect(facts.obligationsMonthly, 42.5);
  });

  test('average monthly spend uses full months with data', () {
    final withHistory = buildFacts(
      now: now,
      expenses: [
        expenseAt(300, DateTime(2026, 9, 3)),
        expenseAt(500, DateTime(2026, 7, 3)),
        expenseAt(9000, DateTime(2026, 6, 3)),
      ],
    );
    expect(withHistory.averageMonthlySpend, 400, reason: 'August is empty');

    final newUser = buildFacts(
      now: now,
      expenses: [expenseAt(100, DateTime(2026, 10, 20))],
    );
    expect(newUser.averageMonthlySpend, newUser.projectedMonthSpend);
  });

  test('savings history', () {
    final facts = buildFacts(
      now: now,
      transfers: [
        transferAt(300, DateTime(2026, 10, 1), goalId: 'g'),
        transferAt(100, DateTime(2026, 10, 10), out: true),
        transferAt(50, DateTime(2026, 10, 15), out: true),
        transferAt(
          200,
          DateTime(2026, 8, 1),
          kind: SavingsTransferKind.periodLeftover,
        ),
        transferAt(10, DateTime(2026, 9, 1), goalId: 'g'),
      ],
    );
    expect(facts.savedLast30, 150);
    expect(facts.savedLast90, 360);
    expect(facts.savedBetween(DateTime(2026, 8), DateTime(2026, 9)), 200);
    expect(facts.withdrawalsLast30, 2);
    expect(facts.leftoverTransfers, 1);
    expect(facts.savingsMonthsCovered, closeTo(81 / 30, 1e-9));
    expect(facts.averageMonthlySaving, closeTo(360 / (81 / 30), 1e-9));
    expect(facts.lastSavedFor('g'), DateTime(2026, 10, 1));
    expect(facts.lastSavedFor('other'), isNull);
  });

  test('savings coverage is between one and three months', () {
    expect(buildFacts(now: now).savingsMonthsCovered, 1);
    expect(
      buildFacts(
        now: now,
        transfers: [transferAt(1, DateTime(2025, 1, 1))],
      ).savingsMonthsCovered,
      3,
    );
  });

  test('logging habits', () {
    final facts = buildFacts(
      now: now,
      expenses: [
        expenseAt(1, DateTime(2026, 10, 20, 8)),
        expenseAt(1, DateTime(2026, 10, 20, 9)),
        expenseAt(1, DateTime(2026, 10, 3)),
        expenseAt(1, DateTime(2026, 9, 25)),
        expenseAt(1, DateTime(2026, 9, 1)),
      ],
    );
    expect(facts.loggedLast30, 4);
    expect(facts.activeDaysLast30, 3);
    expect(facts.noSpendDaysThisMonth, 18);
    expect(facts.weeksOfHistory, 7);
    expect(
      facts.weekdayTotals[DateTime.tuesday],
      3,
      reason: '1 Sep is a Tuesday',
    );
  });

  test('effective income: configured first, else the recent average', () {
    expect(buildFacts(now: now).effectiveMonthlyIncome, isNull);
    expect(
      buildFacts(now: now, monthlyIncome: 900).effectiveMonthlyIncome,
      900,
    );

    final recent = buildFacts(
      now: now,
      incomes: [
        incomeAt(600, DateTime(2026, 10, 1)),
        incomeAt(600, DateTime(2026, 9, 1)),
      ],
    );
    // 50 days of history, so 1200 over 50/30 months.
    expect(recent.incomeLast90, 1200);
    expect(recent.effectiveMonthlyIncome, closeTo(1200 / (50 / 30), 1e-9));

    final young = buildFacts(
      now: now,
      incomes: [incomeAt(500, DateTime(2026, 10, 15))],
    );
    expect(young.effectiveMonthlyIncome, 500, reason: 'at least one month');
  });

  group('GoalFact', () {
    test('ratio, remaining and deadline', () {
      final goal = GoalFact(
        id: 'g',
        name: 'n',
        target: 400,
        saved: 100,
        createdAt: DateTime(2026, 1, 1),
        plannedMonths: 0.25,
      );
      expect(goal.ratio, 0.25);
      expect(goal.remaining, 300);
      expect(goal.deadline, DateTime(2026, 1, 9));

      final over = GoalFact(
        id: 'g',
        name: 'n',
        target: 100,
        saved: 150,
        createdAt: DateTime(2026),
        plannedMonths: 1,
      );
      expect(over.ratio, 1);
      expect(over.remaining, 0);

      final zero = GoalFact(
        id: 'g',
        name: 'n',
        target: 0,
        saved: 5,
        createdAt: DateTime(2026),
        plannedMonths: 1,
      );
      expect(zero.ratio, 0);
    });
  });
}
