// The numbers the smart analysis reasons over, gathered once per run.
// Pure data plus derived figures, so the engine can be tested without
// stores or prefs.

import 'dart:math' as math;

import 'package:waffr/data/models/calendar_period.dart';
import 'package:waffr/data/models/transaction.dart';

/// One active savings goal, as the analysis sees it.
class GoalFact {
  /// The goal's id (used to find its transfers).
  final String id;

  /// The name the user gave the goal.
  final String name;

  /// Target amount.
  final double target;

  /// Saved so far.
  final double saved;

  /// When the goal was created.
  final DateTime createdAt;

  /// Planned length in months (a week counts as a quarter month).
  final double plannedMonths;

  /// A goal snapshot.
  const GoalFact({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    required this.createdAt,
    required this.plannedMonths,
  });

  /// Saved share of the target, 0..1.
  double get ratio => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);

  /// What is still missing, never below zero.
  double get remaining => math.max(0, target - saved);

  /// The end of the planned period (30-day months).
  DateTime get deadline =>
      createdAt.add(Duration(days: (plannedMonths * 30).round()));
}

/// One active recurring bill, as the analysis sees it.
class ObligationFact {
  /// The note, or the category when there is no note.
  final String name;

  /// Amount per charge.
  final double amount;

  /// Approximate cost per month.
  final double monthlyEquivalent;

  /// When the next charge is due.
  final DateTime nextDueAt;

  /// An obligation snapshot.
  const ObligationFact({
    required this.name,
    required this.amount,
    required this.monthlyEquivalent,
    required this.nextDueAt,
  });
}

/// Everything the insight rules read, for the active currency.
///
/// Raw inputs are fields; derived figures are getters or `late final`
/// fields, so each is computed at most once per analysis run.
class SmartFacts {
  /// The moment of the analysis.
  final DateTime now;

  /// Symbol of the active currency, for the generated text.
  final String currencySymbol;

  /// Expenses in the active currency, any date.
  final List<WaffrTransaction> expenses;

  /// Incomes in the active currency, any date.
  final List<WaffrTransaction> incomes;

  /// Savings transfers (in and out) in the active currency.
  final List<WaffrTransaction> savingsTransfers;

  /// Spendable balance now.
  final double balance;

  /// Monthly income from settings, if configured.
  final double? monthlyIncome;

  /// Weekly or monthly cadence of the user's income.
  final RecurringFrequency incomeFrequency;

  /// True when a weekly or monthly income is known.
  final bool hasRecurringIncome;

  /// Money currently parked in savings.
  final double savingsBalance;

  /// Active goals, highest priority first.
  final List<GoalFact> goals;

  /// How many goals were completed.
  final int completedGoals;

  /// Enabled recurring bills.
  final List<ObligationFact> obligations;

  /// Shopping-list items not bought yet.
  final int pendingShopping;

  /// Current usage streak in days.
  final int streakCount;

  /// First day the app was used, if known.
  final DateTime? usageStartedAt;

  /// Facts for one analysis run.
  SmartFacts({
    required this.now,
    required this.currencySymbol,
    required this.expenses,
    required this.incomes,
    required this.savingsTransfers,
    required this.balance,
    required this.monthlyIncome,
    required this.incomeFrequency,
    required this.hasRecurringIncome,
    required this.savingsBalance,
    required this.goals,
    required this.completedGoals,
    required this.obligations,
    required this.pendingShopping,
    required this.streakCount,
    required this.usageStartedAt,
  });

  /// Local midnight of [now].
  DateTime get today => DateTime(now.year, now.month, now.day);

  /// First day of the current month.
  DateTime get monthStart => DateTime(now.year, now.month);

  /// Number of days in the current month.
  int get daysInMonth => DateTime(now.year, now.month + 1, 0).day;

  /// Day of the month, 1-based.
  int get dayOfMonth => now.day;

  /// Days left in the month after today.
  int get daysLeftInMonth => daysInMonth - dayOfMonth;

  /// True when any expense was ever recorded.
  bool get hasExpenses => expenses.isNotEmpty;

  /// Total spent in [start, end).
  double spentBetween(DateTime start, DateTime end) {
    var total = 0.0;
    for (final item in expenses) {
      if (!item.dateTime.isBefore(start) && item.dateTime.isBefore(end)) {
        total += item.amount;
      }
    }
    return total;
  }

  /// Expenses in [start, end).
  List<WaffrTransaction> expensesBetween(DateTime start, DateTime end) => [
    for (final item in expenses)
      if (!item.dateTime.isBefore(start) && item.dateTime.isBefore(end)) item,
  ];

  /// Spending per category in [start, end); no category counts as "أخرى".
  Map<String, double> categoryTotals(DateTime start, DateTime end) {
    final totals = <String, double>{};
    for (final item in expensesBetween(start, end)) {
      final key = item.category ?? 'أخرى';
      totals[key] = (totals[key] ?? 0) + item.amount;
    }
    return totals;
  }

  // Month to date, and the same number of days of last month, so a
  // comparison on the 10th is not against a full month.
  late final DateTime _tomorrow = today.add(const Duration(days: 1));

  /// First day of last month.
  late final DateTime prevMonthStart = DateTime(now.year, now.month - 1);

  /// The day after today's date in last month (end of the same span).
  late final DateTime prevMonthSameDay = () {
    final prevDays = DateTime(now.year, now.month, 0).day;
    final day = math.min(dayOfMonth, prevDays);
    return DateTime(prevMonthStart.year, prevMonthStart.month, day + 1);
  }();

  /// Spent this month so far.
  late final double monthSpent = spentBetween(monthStart, _tomorrow);

  /// Spent over the same days of last month.
  late final double prevMonthSpentSameSpan = spentBetween(
    prevMonthStart,
    prevMonthSameDay,
  );

  /// This month's spending per category.
  late final Map<String, double> monthCategories = categoryTotals(
    monthStart,
    _tomorrow,
  );

  /// Last month's spending per category over the same days.
  late final Map<String, double> prevMonthCategories = categoryTotals(
    prevMonthStart,
    prevMonthSameDay,
  );

  /// First day of this week (Saturday).
  late final DateTime weekStart = CalendarPeriod.weekStart(now);

  /// Spent this week so far.
  late final double weekSpent = spentBetween(weekStart, _tomorrow);

  /// Spent over the same days of last week.
  late final double prevWeekSpentSameSpan = spentBetween(
    weekStart.subtract(const Duration(days: 7)),
    _tomorrow.subtract(const Duration(days: 7)),
  );

  /// Average spent per day this month.
  double get dailyAverageThisMonth =>
      dayOfMonth <= 0 ? 0 : monthSpent / dayOfMonth;

  /// Recent daily pace over the last two weeks (or since the first
  /// expense), steadier than month to date early in the month.
  late final double dailyAverageRecent = () {
    final start = today.subtract(const Duration(days: 13));
    final first = expenses.isEmpty
        ? today
        : expenses
              .map((e) => e.dateTime)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    final from = first.isAfter(start)
        ? DateTime(first.year, first.month, first.day)
        : start;
    final days = math.max(1, _tomorrow.difference(from).inDays);
    return spentBetween(from, _tomorrow) / days;
  }();

  /// Month-end spending if the recent pace continues.
  double get projectedMonthSpend =>
      monthSpent + dailyAverageRecent * daysLeftInMonth;

  /// Days of balance left at the recent pace; null when nothing is spent.
  double? get runwayDays =>
      dailyAverageRecent <= 0 ? null : balance / dailyAverageRecent;

  /// Days until the next income period starts; null without a recurring
  /// income.
  int? get daysUntilIncome {
    if (!hasRecurringIncome || incomeFrequency == RecurringFrequency.none) {
      return null;
    }
    final next = CalendarPeriod.ofFrequency(incomeFrequency, now).end;
    return next.difference(today).inDays;
  }

  /// Monthly cost of all recurring bills.
  double get obligationsMonthly =>
      obligations.fold(0.0, (sum, item) => sum + item.monthlyEquivalent);

  /// Average monthly spending over the last three full months that have
  /// data, falling back to the projection for new users.
  late final double averageMonthlySpend = () {
    final totals = <double>[];
    for (var back = 1; back <= 3; back++) {
      final start = DateTime(now.year, now.month - back);
      final end = DateTime(now.year, now.month - back + 1);
      final total = spentBetween(start, end);
      if (total > 0) totals.add(total);
    }
    if (totals.isEmpty) return projectedMonthSpend;
    return totals.reduce((a, b) => a + b) / totals.length;
  }();

  /// Net saved (in minus out) in [start, end).
  double savedBetween(DateTime start, DateTime end) {
    var total = 0.0;
    for (final item in savingsTransfers) {
      if (item.dateTime.isBefore(start) || !item.dateTime.isBefore(end)) {
        continue;
      }
      if (item.isSavingsIn) total += item.amount;
      if (item.isSavingsOut) total -= item.amount;
    }
    return total;
  }

  /// Net saved over the last 30 days.
  late final double savedLast30 = savedBetween(
    today.subtract(const Duration(days: 29)),
    _tomorrow,
  );

  /// Net saved over the last 90 days.
  late final double savedLast90 = savedBetween(
    today.subtract(const Duration(days: 89)),
    _tomorrow,
  );

  /// Withdrawals from savings in the last 30 days.
  int get withdrawalsLast30 => savingsTransfers
      .where(
        (item) =>
            item.isSavingsOut &&
            item.dateTime.isAfter(today.subtract(const Duration(days: 30))),
      )
      .length;

  /// How many period leftovers were moved to savings.
  int get leftoverTransfers => savingsTransfers
      .where(
        (item) =>
            item.isSavingsIn &&
            item.transferKind == SavingsTransferKind.periodLeftover,
      )
      .length;

  /// Months of history covered by savings, between one and three, so a new
  /// user's first month is not averaged over three.
  double get savingsMonthsCovered {
    if (savingsTransfers.isEmpty) return 1;
    final first = savingsTransfers
        .map((e) => e.dateTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final days = today.difference(first).inDays + 1;
    return (days / 30).clamp(1.0, 3.0);
  }

  /// Average net saving per month over the covered history.
  double get averageMonthlySaving =>
      math.max(0, savedLast90) / savingsMonthsCovered;

  /// When money was last moved into the goal [goalId], if ever.
  DateTime? lastSavedFor(String goalId) {
    DateTime? last;
    for (final item in savingsTransfers) {
      if (item.isSavingsIn && item.goalId == goalId) {
        if (last == null || item.dateTime.isAfter(last)) last = item.dateTime;
      }
    }
    return last;
  }

  /// Time of the newest expense, if any.
  DateTime? get lastExpenseAt => expenses.isEmpty
      ? null
      : expenses.map((e) => e.dateTime).reduce((a, b) => a.isAfter(b) ? a : b);

  /// Expenses logged in the last 30 days.
  int get loggedLast30 => expenses
      .where(
        (e) => e.dateTime.isAfter(today.subtract(const Duration(days: 30))),
      )
      .length;

  /// Distinct days with at least one expense in the last 30 days.
  int get activeDaysLast30 => {
    for (final e in expenses)
      if (e.dateTime.isAfter(today.subtract(const Duration(days: 30))))
        DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day),
  }.length;

  /// Days of this month so far without any expense.
  int get noSpendDaysThisMonth {
    final spentDays = {
      for (final e in expensesBetween(monthStart, _tomorrow)) e.dateTime.day,
    };
    return dayOfMonth - spentDays.length;
  }

  /// Total spent per weekday (DateTime.monday..sunday) over the last 8 weeks.
  Map<int, double> get weekdayTotals {
    final totals = <int, double>{};
    final from = today.subtract(const Duration(days: 55));
    for (final e in expensesBetween(from, _tomorrow)) {
      totals[e.dateTime.weekday] = (totals[e.dateTime.weekday] ?? 0) + e.amount;
    }
    return totals;
  }

  /// Whole weeks since the first expense.
  int get weeksOfHistory {
    final first = expenses.isEmpty
        ? today
        : expenses
              .map((e) => e.dateTime)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    return today.difference(first).inDays ~/ 7;
  }

  /// Income recorded over the last 90 days.
  double get incomeLast90 {
    final from = today.subtract(const Duration(days: 89));
    return incomes
        .where((e) => !e.dateTime.isBefore(from))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Income the analysis can rely on: the configured monthly amount, or
  /// the last 90 days averaged per month.
  double? get effectiveMonthlyIncome {
    if ((monthlyIncome ?? 0) > 0) return monthlyIncome;
    final recent = incomeLast90;
    if (recent <= 0) return null;
    final first = incomes
        .map((e) => e.dateTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final months = ((today.difference(first).inDays + 1) / 30).clamp(1.0, 3.0);
    return recent / months;
  }
}
