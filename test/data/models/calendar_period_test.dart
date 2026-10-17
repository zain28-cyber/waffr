// CalendarPeriod math: Saturday weeks, month keys, key parsing, completed
// period lists, savings-chart windows and their Arabic labels.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/calendar_period.dart';
import 'package:waffr/data/models/transaction.dart';

void main() {
  group('weekStart', () {
    test('weeks start on Saturday', () {
      // 2026-10-10 is a Saturday.
      expect(
        CalendarPeriod.weekStart(DateTime(2026, 10, 10, 23)),
        DateTime(2026, 10, 10),
      );
      expect(
        CalendarPeriod.weekStart(DateTime(2026, 10, 16, 8)),
        DateTime(2026, 10, 10),
        reason: 'Friday closes the week',
      );
      expect(
        CalendarPeriod.weekStart(DateTime(2026, 10, 17)),
        DateTime(2026, 10, 17),
      );
    });

    test('crosses month and year boundaries', () {
      // Thursday 1 Jan 2026 belongs to the week of Saturday 27 Dec 2025.
      expect(
        CalendarPeriod.weekStart(DateTime(2026, 1, 1)),
        DateTime(2025, 12, 27),
      );
    });
  });

  group('keys', () {
    test('weekly and monthly keys', () {
      expect(CalendarPeriod.weeklyKey(DateTime(2026, 10, 14)), 'w:2026-10-10');
      expect(CalendarPeriod.monthlyKey(DateTime(2026, 3, 31)), 'm:2026-03');
      expect(
        CalendarPeriod.keyFor(
          RecurringFrequency.weekly,
          DateTime(2026, 10, 14),
        ),
        'w:2026-10-10',
      );
      expect(
        CalendarPeriod.keyFor(RecurringFrequency.monthly, DateTime(2026, 1, 9)),
        'm:2026-01',
      );
      expect(
        CalendarPeriod.keyFor(RecurringFrequency.none, DateTime(2026, 1, 9)),
        '',
      );
    });

    test('a period names itself by its shape', () {
      final week = CalendarPeriod.ofFrequency(
        RecurringFrequency.weekly,
        DateTime(2026, 10, 14),
      );
      final month = CalendarPeriod.ofFrequency(
        RecurringFrequency.monthly,
        DateTime(2026, 2, 14),
      );
      final custom = CalendarPeriod(
        start: DateTime(2026, 1, 5),
        end: DateTime(2026, 1, 9),
      );

      expect(week.key, 'w:2026-10-10');
      expect(month.key, 'm:2026-02');
      expect(custom.key, '2026-01-05_2026-01-09');
    });

    test('parseKey turns weekly and monthly keys back into periods', () {
      final week = CalendarPeriod.parseKey('w:2026-10-14')!;
      expect(week.start, DateTime(2026, 10, 10), reason: 'snaps to Saturday');
      expect(week.end, DateTime(2026, 10, 17));

      final month = CalendarPeriod.parseKey('m:2026-12')!;
      expect(month.start, DateTime(2026, 12));
      expect(month.end, DateTime(2027));
    });

    test('parseKey rejects malformed keys', () {
      expect(CalendarPeriod.parseKey(''), isNull);
      expect(CalendarPeriod.parseKey('w:not-a-date'), isNull);
      expect(CalendarPeriod.parseKey('m:2026'), isNull);
      expect(CalendarPeriod.parseKey('m:x-y'), isNull);
      expect(CalendarPeriod.parseKey('leftover:m:2026-01'), isNull);
    });
  });

  group('ofFrequency / nextStart', () {
    test('none is a single day', () {
      final day = CalendarPeriod.ofFrequency(
        RecurringFrequency.none,
        DateTime(2026, 5, 6, 15),
      );
      expect(day.start, DateTime(2026, 5, 6));
      expect(day.end, DateTime(2026, 5, 7));
    });

    test('next start steps one period', () {
      expect(
        CalendarPeriod.nextStart(
          RecurringFrequency.weekly,
          DateTime(2026, 1, 3),
        ),
        DateTime(2026, 1, 10),
      );
      expect(
        CalendarPeriod.nextStart(
          RecurringFrequency.monthly,
          DateTime(2026, 12),
        ),
        DateTime(2027),
      );
      expect(
        CalendarPeriod.nextStart(
          RecurringFrequency.none,
          DateTime(2026, 1, 31),
        ),
        DateTime(2026, 2, 1),
      );
    });

    test('contains is half-open', () {
      final period = CalendarPeriod(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 2, 1),
      );
      expect(period.contains(DateTime(2026, 1, 1)), isTrue);
      expect(period.contains(DateTime(2026, 1, 31, 23, 59)), isTrue);
      expect(period.contains(DateTime(2026, 2, 1)), isFalse);
      expect(period.contains(DateTime(2025, 12, 31)), isFalse);
    });

    test('isComplete compares the end with now', () {
      expect(
        CalendarPeriod(
          start: DateTime(2000),
          end: DateTime(2000, 2),
        ).isComplete,
        isTrue,
      );
      expect(
        CalendarPeriod(start: DateTime(2000), end: DateTime(3000)).isComplete,
        isFalse,
      );
    });
  });

  group('completedKeysSince', () {
    test('lists finished months up to the current one', () {
      expect(
        CalendarPeriod.completedKeysSince(
          RecurringFrequency.monthly,
          DateTime(2026, 7, 20),
          DateTime(2026, 10, 12),
        ),
        ['m:2026-07', 'm:2026-08', 'm:2026-09'],
      );
    });

    test('lists finished weeks and stops at the current week', () {
      expect(
        CalendarPeriod.completedKeysSince(
          RecurringFrequency.weekly,
          DateTime(2026, 9, 28),
          DateTime(2026, 10, 12),
        ),
        ['w:2026-09-26', 'w:2026-10-03'],
      );
    });

    test('nothing for none, or when still in the first period', () {
      expect(
        CalendarPeriod.completedKeysSince(
          RecurringFrequency.none,
          DateTime(2020),
          DateTime(2026),
        ),
        isEmpty,
      );
      expect(
        CalendarPeriod.completedKeysSince(
          RecurringFrequency.monthly,
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 31),
        ),
        isEmpty,
      );
    });

    test('is capped by maxKeys', () {
      expect(
        CalendarPeriod.completedKeysSince(
          RecurringFrequency.monthly,
          DateTime(2000),
          DateTime(2026),
          maxKeys: 5,
        ),
        hasLength(5),
      );
    });
  });

  group('forRange', () {
    final now = DateTime(2026, 8, 19, 15); // Wednesday

    test('week windows step back seven days', () {
      final current = CalendarPeriod.forRange(SavingsRange.week, 0, now: now);
      expect(current.start, DateTime(2026, 8, 15));
      expect(current.end, DateTime(2026, 8, 22));

      final previous = CalendarPeriod.forRange(SavingsRange.week, 1, now: now);
      expect(previous.start, DateTime(2026, 8, 8));
    });

    test('month windows cross the year', () {
      final period = CalendarPeriod.forRange(SavingsRange.month, 8, now: now);
      expect(period.start, DateTime(2025, 12));
      expect(period.end, DateTime(2026, 1));
    });

    test('quarter, half-year and year windows align to the calendar', () {
      final quarter = CalendarPeriod.forRange(
        SavingsRange.threeMonths,
        0,
        now: now,
      );
      expect(quarter.start, DateTime(2026, 7));
      expect(quarter.end, DateTime(2026, 10));

      final previousQuarter = CalendarPeriod.forRange(
        SavingsRange.threeMonths,
        3,
        now: now,
      );
      expect(previousQuarter.start, DateTime(2025, 10));

      final half = CalendarPeriod.forRange(SavingsRange.sixMonths, 1, now: now);
      expect(half.start, DateTime(2026, 1));
      expect(half.end, DateTime(2026, 7));

      final year = CalendarPeriod.forRange(SavingsRange.year, 2, now: now);
      expect(year.start, DateTime(2024));
      expect(year.end, DateTime(2025));
    });
  });

  group('labels', () {
    test('range labels in Arabic month names', () {
      expect(
        CalendarPeriod.rangeLabel(
          SavingsRange.week,
          CalendarPeriod(
            start: DateTime(2026, 8, 15),
            end: DateTime(2026, 8, 22),
          ),
        ),
        '15 – 21 آب 2026',
      );
      expect(
        CalendarPeriod.rangeLabel(
          SavingsRange.week,
          CalendarPeriod(
            start: DateTime(2026, 8, 29),
            end: DateTime(2026, 9, 5),
          ),
        ),
        '29 آب – 4 أيلول 2026',
      );
      expect(
        CalendarPeriod.rangeLabel(
          SavingsRange.month,
          CalendarPeriod(start: DateTime(2026, 1), end: DateTime(2026, 2)),
        ),
        'كانون الثاني 2026',
      );
      expect(
        CalendarPeriod.rangeLabel(
          SavingsRange.threeMonths,
          CalendarPeriod(start: DateTime(2026, 7), end: DateTime(2026, 10)),
        ),
        'تموز – أيلول 2026',
      );
      expect(
        CalendarPeriod.rangeLabel(
          SavingsRange.sixMonths,
          CalendarPeriod(start: DateTime(2025, 10), end: DateTime(2026, 4)),
        ),
        'تشرين الأول 2025 – آذار 2026',
      );
      expect(
        CalendarPeriod.rangeLabel(
          SavingsRange.year,
          CalendarPeriod(start: DateTime(2025), end: DateTime(2026)),
        ),
        '2025',
      );
    });

    test('captions, chip labels and month names', () {
      expect(
        CalendarPeriod.currentPeriodCaption(SavingsRange.week),
        'هذا الأسبوع',
      );
      expect(
        CalendarPeriod.currentPeriodCaption(SavingsRange.year),
        'هذه السنة',
      );
      expect(SavingsRange.threeMonths.label, '3 أشهر');
      expect(SavingsRange.values.map((r) => r.label).toSet(), hasLength(5));
      expect(CalendarPeriod.monthNames, hasLength(12));
      expect(CalendarPeriod.monthName(1), 'كانون الثاني');
      expect(CalendarPeriod.monthName(12), 'كانون الأول');
      expect(() => CalendarPeriod.monthName(13), throwsRangeError);
    });
  });
}
