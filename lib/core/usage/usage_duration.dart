// Compact Arabic duration from the first local usage day.

import 'package:waffr/core/utils/calendar_days.dart';

/// How long since [start], in Arabic: "اليوم", days, months and days, or
/// years and months (30-day months).
String usageDurationText(DateTime start, DateTime now) {
  final startDay = DateTime(start.year, start.month, start.day);
  final today = DateTime(now.year, now.month, now.day);
  var days = calendarDaysBetween(startDay, today);
  if (days <= 0) return 'اليوم';
  if (days < 30) return _days(days);

  final months = days ~/ 30;
  final remainder = days % 30;
  if (months < 12) {
    if (remainder == 0) return _months(months);
    return '${_months(months)} و${_days(remainder)}';
  }

  final years = months ~/ 12;
  final remMonths = months % 12;
  if (remMonths == 0) return _years(years);
  return '${_years(years)} و${_months(remMonths)}';
}

/// A day count with the noun that agrees with it.
String _days(int value) {
  if (value == 1) return 'يوم';
  if (value == 2) return 'يومان';
  if (value >= 3 && value <= 10) return '$value أيام';
  return '$value يوماً';
}

/// A month count with the noun that agrees with it.
String _months(int value) {
  if (value == 1) return 'شهر';
  if (value == 2) return 'شهران';
  if (value >= 3 && value <= 10) return '$value أشهر';
  return '$value شهراً';
}

/// A year count with the noun that agrees with it.
String _years(int value) {
  if (value == 1) return 'سنة';
  if (value == 2) return 'سنتان';
  if (value >= 3 && value <= 10) return '$value سنوات';
  return '$value سنة';
}
