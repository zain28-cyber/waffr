// Calendar-day arithmetic that ignores daylight-saving shifts.
//
// `a.difference(b).inDays` and `date.add(Duration(days: n))` count 24-hour
// blocks, so across a DST switch a 23-hour day rounds down to zero days and
// adding a week lands an hour off midnight. These helpers count dates.

/// Whole calendar days from [from] to [to] (negative when [to] is earlier).
/// The time of day is ignored and a 23- or 25-hour day still counts as one.
int calendarDaysBetween(DateTime from, DateTime to) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

/// Local midnight [days] calendar days after [date]'s day (before it for a
/// negative count).
DateTime addCalendarDays(DateTime date, int days) {
  return DateTime(date.year, date.month, date.day + days);
}
