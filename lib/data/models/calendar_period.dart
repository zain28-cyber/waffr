// Week/month (and savings-range) windows used for income periods and reports.

import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/core/utils/calendar_days.dart';

/// Window sizes of the savings period pager.
enum SavingsRange {
  /// One week (Saturday to Friday).
  week,

  /// One calendar month.
  month,

  /// A calendar quarter.
  threeMonths,

  /// A calendar half year.
  sixMonths,

  /// A calendar year.
  year,
}

/// Arabic name of each [SavingsRange].
extension SavingsRangeLabel on SavingsRange {
  /// Chip text ("شهر").
  String get label => switch (this) {
    SavingsRange.week => 'أسبوع',
    SavingsRange.month => 'شهر',
    SavingsRange.threeMonths => '3 أشهر',
    SavingsRange.sixMonths => '6 أشهر',
    SavingsRange.year => 'سنة',
  };
}

/// Half-open [start, end) calendar slice plus helpers for keys and ranges.
class CalendarPeriod {
  /// First instant inside the period.
  final DateTime start;

  /// First instant after the period.
  final DateTime end;

  /// A period from [start] (inclusive) to [end] (exclusive).
  const CalendarPeriod({required this.start, required this.end});

  /// True when [date] falls inside the period.
  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);

  /// True once the period is over.
  bool get isComplete {
    final now = DateTime.now();
    return !now.isBefore(end);
  }

  /// Compact id: weekly `w:…`, monthly `m:…`, or start_end day stamps.
  String get key {
    if (calendarDaysBetween(start, end) == 7) {
      return weeklyKey(start);
    }
    if (start.day == 1 && end == DateTime(start.year, start.month + 1)) {
      return monthlyKey(start);
    }
    return '${_isoDay(start)}_${_isoDay(end)}';
  }

  /// Weeks start Saturday, same rule as ReportScreen.
  static DateTime weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final daysFromSaturday = (day.weekday + 1) % 7;
    return addCalendarDays(day, -daysFromSaturday);
  }

  /// First day of [date]'s month.
  static DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

  /// `w:YYYY-MM-DD` of the week holding [date].
  static String weeklyKey(DateTime date) {
    final start = weekStart(date);
    return 'w:${_isoDay(start)}';
  }

  /// `m:YYYY-MM` of the month holding [date].
  static String monthlyKey(DateTime date) {
    final start = monthStart(date);
    return 'm:${start.year}-${_two(start.month)}';
  }

  /// The weekly or monthly key of [date]; empty for no frequency.
  static String keyFor(RecurringFrequency frequency, DateTime date) {
    return switch (frequency) {
      RecurringFrequency.weekly => weeklyKey(date),
      RecurringFrequency.monthly => monthlyKey(date),
      RecurringFrequency.none => '',
    };
  }

  /// Turns a stored `w:` / `m:` key back into a period, or null if malformed.
  static CalendarPeriod? parseKey(String key) {
    if (key.startsWith('w:')) {
      final date = DateTime.tryParse(key.substring(2));
      if (date == null) return null;
      final start = weekStart(date);
      return CalendarPeriod(start: start, end: addCalendarDays(start, 7));
    }
    if (key.startsWith('m:')) {
      final parts = key.substring(2).split('-');
      if (parts.length < 2) return null;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year == null || month == null) return null;
      final start = DateTime(year, month);
      return CalendarPeriod(
        start: start,
        end: DateTime(start.year, start.month + 1),
      );
    }
    return null;
  }

  /// The week, month or day (for none) holding [date].
  static CalendarPeriod ofFrequency(
    RecurringFrequency frequency,
    DateTime date,
  ) {
    switch (frequency) {
      case RecurringFrequency.weekly:
        final start = weekStart(date);
        return CalendarPeriod(start: start, end: addCalendarDays(start, 7));
      case RecurringFrequency.monthly:
        final start = monthStart(date);
        return CalendarPeriod(
          start: start,
          end: DateTime(start.year, start.month + 1),
        );
      case RecurringFrequency.none:
        final day = DateTime(date.year, date.month, date.day);
        return CalendarPeriod(start: day, end: addCalendarDays(day, 1));
    }
  }

  /// The start of the period after the one starting at [start].
  static DateTime nextStart(RecurringFrequency frequency, DateTime start) {
    return switch (frequency) {
      RecurringFrequency.weekly => addCalendarDays(start, 7),
      RecurringFrequency.monthly => DateTime(start.year, start.month + 1),
      RecurringFrequency.none => addCalendarDays(start, 1),
    };
  }

  /// Finished period keys from [since] up to (but not including) the current one.
  static List<String> completedKeysSince(
    RecurringFrequency frequency,
    DateTime since,
    DateTime now, {
    int maxKeys = 120,
  }) {
    if (frequency == RecurringFrequency.none) return const [];

    final keys = <String>[];
    var cursor = ofFrequency(frequency, since).start;
    final currentStart = ofFrequency(frequency, now).start;

    while (cursor.isBefore(currentStart) && keys.length < maxKeys) {
      keys.add(keyFor(frequency, cursor));
      cursor = nextStart(frequency, cursor);
    }
    return keys;
  }

  /// Builds a savings-chart window; [offset] steps back by one range each time.
  static CalendarPeriod forRange(
    SavingsRange range,
    int offset, {
    DateTime? now,
  }) {
    final moment = now ?? DateTime.now();
    final today = DateTime(moment.year, moment.month, moment.day);
    late DateTime start;
    late DateTime end;

    switch (range) {
      case SavingsRange.week:
        start = addCalendarDays(weekStart(today), -offset * 7);
        end = addCalendarDays(start, 7);
      case SavingsRange.month:
        start = DateTime(moment.year, moment.month - offset);
        end = DateTime(start.year, start.month + 1);
      case SavingsRange.threeMonths:
        final quarterStartMonth = ((moment.month - 1) ~/ 3) * 3 + 1;
        start = DateTime(moment.year, quarterStartMonth - offset * 3);
        end = DateTime(start.year, start.month + 3);
      case SavingsRange.sixMonths:
        final halfStartMonth = moment.month <= 6 ? 1 : 7;
        start = DateTime(moment.year, halfStartMonth - offset * 6);
        end = DateTime(start.year, start.month + 6);
      case SavingsRange.year:
        start = DateTime(moment.year - offset);
        end = DateTime(start.year + 1);
    }

    return CalendarPeriod(start: start, end: end);
  }

  /// Arabic label for a chart period (day span, month name, or year).
  static String rangeLabel(SavingsRange range, CalendarPeriod period) {
    final lastDay = addCalendarDays(period.end, -1);
    switch (range) {
      case SavingsRange.week:
        if (period.start.month == lastDay.month &&
            period.start.year == lastDay.year) {
          return '${period.start.day} – ${lastDay.day} '
              '${monthName(period.start.month)} ${period.start.year}';
        }
        return '${period.start.day} ${monthName(period.start.month)}'
            ' – ${lastDay.day} ${monthName(lastDay.month)} ${lastDay.year}';
      case SavingsRange.month:
        return '${monthName(period.start.month)} ${period.start.year}';
      case SavingsRange.threeMonths:
      case SavingsRange.sixMonths:
        if (period.start.year == lastDay.year) {
          return '${monthName(period.start.month)} – '
              '${monthName(lastDay.month)} ${lastDay.year}';
        }
        return '${monthName(period.start.month)} ${period.start.year} – '
            '${monthName(lastDay.month)} ${lastDay.year}';
      case SavingsRange.year:
        return period.start.year.toString();
    }
  }

  /// "This week", "this month"... for the current window of [range].
  static String currentPeriodCaption(SavingsRange range) {
    return switch (range) {
      SavingsRange.week => 'هذا الأسبوع',
      SavingsRange.month => 'هذا الشهر',
      SavingsRange.threeMonths => 'هذه الأشهر الثلاثة',
      SavingsRange.sixMonths => 'هذه الأشهر الستة',
      SavingsRange.year => 'هذه السنة',
    };
  }

  /// Levantine month names, January first.
  static const List<String> monthNames = [
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول',
  ];

  /// The name of [month] (1-12).
  static String monthName(int month) => monthNames[month - 1];

  static String _isoDay(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}
