// Calendar-day streak rules. A day counts once; missing a full day restarts at 1.

import 'package:waffr/core/utils/calendar_days.dart';

/// A streak at one moment: the run length, its last counted day, and when
/// usage started.
class StreakSnapshot {
  /// Consecutive days counted, 0 before the first.
  final int count;

  /// The last calendar day that counted.
  final DateTime? lastDay;

  /// The first day the app was used.
  final DateTime? startedAt;

  /// A snapshot; empty by default.
  const StreakSnapshot({this.count = 0, this.lastDay, this.startedAt});

  /// Day one is exactly this phrase. Later days show the consecutive count.
  String get label => count <= 1 ? 'اليوم الأول' : '$count أيام متواصلة';

  /// Local midnight of [value].
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// "YYYY-MM-DD" of [value], the format the server stores.
  static String? dayKey(DateTime? value) {
    if (value == null) return null;
    final day = dateOnly(value);
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  /// A day from [dayKey] text, or null when malformed.
  static DateTime? parseDayKey(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }
}

/// Pure streak rules shared by the service, sync merge and tests.
class StreakMath {
  /// The streak as it stands at [now]. A last day before yesterday means a
  /// whole calendar day was skipped, so the streak is broken (0) even before
  /// the app records today.
  static int currentCount(StreakSnapshot state, DateTime now) {
    final last = state.lastDay;
    if (last == null || state.count < 1) return 0;
    final yesterday = StreakSnapshot.dateOnly(now)
        .subtract(const Duration(days: 1));
    if (StreakSnapshot.dateOnly(last).isBefore(yesterday)) return 0;
    return state.count;
  }

  /// [current] after opening the app at [now]: today counts once,
  /// yesterday extends the run, an older last day restarts it at 1.
  static StreakSnapshot record(StreakSnapshot current, DateTime now) {
    final today = StreakSnapshot.dateOnly(now);
    final started = _earlier(current.startedAt, today) ?? today;
    final last = current.lastDay == null
        ? null
        : StreakSnapshot.dateOnly(current.lastDay!);

    if (last == null) {
      return StreakSnapshot(count: 1, lastDay: today, startedAt: started);
    }
    if (!last.isBefore(today)) {
      final count = current.count < 1 ? 1 : current.count;
      return StreakSnapshot(count: count, lastDay: today, startedAt: started);
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (last == yesterday) {
      final base = current.count < 1 ? 1 : current.count;
      return StreakSnapshot(
        count: base + 1,
        lastDay: today,
        startedAt: started,
      );
    }

    return StreakSnapshot(count: 1, lastDay: today, startedAt: started);
  }

  /// Keeps the further calendar day. A fresh local "day 1" does not wipe a
  /// streak whose last day was yesterday.
  static StreakSnapshot merge(StreakSnapshot local, StreakSnapshot remote) {
    final started = _earlier(local.startedAt, remote.startedAt);

    if (remote.lastDay == null) {
      return StreakSnapshot(
        count: local.count,
        lastDay: local.lastDay,
        startedAt: started ?? local.startedAt,
      );
    }
    if (local.lastDay == null) {
      final count = remote.count < 1 ? 1 : remote.count;
      return StreakSnapshot(
        count: count,
        lastDay: StreakSnapshot.dateOnly(remote.lastDay!),
        startedAt: started,
      );
    }

    final localDay = StreakSnapshot.dateOnly(local.lastDay!);
    final remoteDay = StreakSnapshot.dateOnly(remote.lastDay!);
    if (localDay == remoteDay) {
      final count = local.count > remote.count ? local.count : remote.count;
      return StreakSnapshot(
        count: count < 1 ? 1 : count,
        lastDay: localDay,
        startedAt: started,
      );
    }

    final laterIsLocal = localDay.isAfter(remoteDay);
    final later = laterIsLocal ? local : remote;
    final earlier = laterIsLocal ? remote : local;
    final laterDay = StreakSnapshot.dateOnly(later.lastDay!);
    final earlierDay = StreakSnapshot.dateOnly(earlier.lastDay!);
    final gap = calendarDaysBetween(earlierDay, laterDay);
    var count = later.count < 1 ? 1 : later.count;
    if (gap == 1 && count <= 1 && earlier.count > 1) {
      count = earlier.count + 1;
    }
    return StreakSnapshot(count: count, lastDay: laterDay, startedAt: started);
  }

  /// True when the two snapshots would store differently.
  static bool differs(StreakSnapshot left, StreakSnapshot right) {
    return left.count != right.count ||
        StreakSnapshot.dayKey(left.lastDay) !=
            StreakSnapshot.dayKey(right.lastDay) ||
        _dayKeyOrIso(left.startedAt) != _dayKeyOrIso(right.startedAt);
  }

  /// The earlier of two optional dates.
  static DateTime? _earlier(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  /// A start date compared by day only.
  static String? _dayKeyOrIso(DateTime? value) {
    if (value == null) return null;
    return StreakSnapshot.dayKey(value);
  }
}

const List<int> _streakMilestones = [3, 7, 14, 30, 60, 100, 180, 365];

/// Next round number of days worth aiming for.
int nextStreakMilestone(int count) {
  for (final value in _streakMilestones) {
    if (value > count) return value;
  }
  return (count ~/ 365 + 1) * 365;
}
