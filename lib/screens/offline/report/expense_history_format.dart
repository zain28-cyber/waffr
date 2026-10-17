// Shared pieces of the expense-history export: grouping by day, day labels,
// totals per currency, and the plain-text version. Pure Dart, so the PDF
// renderer can use it inside a background isolate.

import 'package:waffr/core/utils/money.dart';
import 'package:waffr/data/models/calendar_period.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/core/utils/calendar_days.dart';

/// One calendar day of the export and its expenses, newest first.
class ExpenseShareDay {
  /// Local midnight of the day.
  final DateTime date;

  /// The day's expenses, newest first.
  final List<WaffrTransaction> expenses;

  /// Groups [expenses] under [date].
  const ExpenseShareDay(this.date, this.expenses);
}

/// [expenses] grouped by local calendar day, newest day first.
List<ExpenseShareDay> groupExpensesForShare(List<WaffrTransaction> expenses) {
  final grouped = <DateTime, List<WaffrTransaction>>{};
  for (final expense in expenses) {
    final local = expense.dateTime.toLocal();
    final date = DateTime(local.year, local.month, local.day);
    grouped.putIfAbsent(date, () => []).add(expense);
  }
  final days =
      grouped.entries
          .map((entry) => ExpenseShareDay(entry.key, entry.value))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  for (final day in days) {
    day.expenses.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }
  return days;
}

/// "اليوم", "أمس", or the day and month name (with the year when it is
/// not the current one).
String expenseShareDayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final difference = calendarDaysBetween(date, today);
  if (difference == 0) return 'اليوم';
  if (difference == 1) return 'أمس';
  if (date.year == today.year) {
    return '${date.day} ${CalendarPeriod.monthName(date.month)}';
  }
  return '${date.day} ${CalendarPeriod.monthName(date.month)} ${date.year}';
}

/// The plain-text export: one block per day, then the grand total.
String buildExpenseHistoryText(List<WaffrTransaction> expenses) {
  final days = groupExpensesForShare(expenses);
  final buffer = StringBuffer('سجل المصروفات\n');
  // One block per day: label, expense lines (with notes), day total.
  for (final day in days) {
    buffer.writeln();
    buffer.writeln(expenseShareDayLabel(day.date));
    for (final expense in day.expenses) {
      buffer.writeln(_expenseLine(expense));
      final note = expense.note?.trim();
      if (note != null && note.isNotEmpty) {
        buffer.writeln(note);
      }
    }
    buffer.writeln(_totalsLine('مجموع اليوم', day.expenses));
  }
  buffer.writeln();
  buffer.writeln(_totalsLine('المجموع', expenses));
  return buffer.toString().trimRight();
}

/// One expense's amount with its currency symbol.
String expenseAmountText(WaffrTransaction expense) {
  return '${formatMoney(expense.amount)} ${currencyLabelFor(expense.currencyCode)}';
}

/// Sum per currency, joined with dots ("1,500 ل.س  •  20 \$").
String expenseTotalsText(List<WaffrTransaction> expenses) {
  final totals = <String, double>{};
  for (final expense in expenses) {
    totals.update(
      expense.currencyCode,
      (value) => value + expense.amount,
      ifAbsent: () => expense.amount,
    );
  }
  return totals.entries
      .map(
        (entry) => '${formatMoney(entry.value)} ${currencyLabelFor(entry.key)}',
      )
      .join('  •  ');
}

/// One expense as "category  •  time  •  amount currency".
String _expenseLine(WaffrTransaction expense) {
  final category = categoryFor(expense.category).label;
  final amount = formatMoney(expense.amount);
  final currency = currencyLabelFor(expense.currencyCode);
  final time = formatTime(expense.dateTime);
  return '$category  •  $time  •  $amount $currency';
}

/// "[label]: " followed by the per-currency totals of [expenses].
String _totalsLine(String label, List<WaffrTransaction> expenses) {
  return '$label: ${expenseTotalsText(expenses)}';
}
