// StreakMath and StreakSnapshot: day keys, the current count with skipped
// days, recording a day, merging two devices, the differs check and the
// next milestone.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/usage/streak_math.dart';

void main() {
  StreakSnapshot at(int count, DateTime? last, {DateTime? started}) =>
      StreakSnapshot(count: count, lastDay: last, startedAt: started);

  group('StreakSnapshot', () {
    test('day keys round trip and reject malformed text', () {
      expect(StreakSnapshot.dayKey(DateTime(2026, 3, 4, 23, 59)), '2026-03-04');
      expect(StreakSnapshot.dayKey(null), isNull);
      expect(StreakSnapshot.parseDayKey('2026-03-04'), DateTime(2026, 3, 4));
      expect(StreakSnapshot.parseDayKey(''), isNull);
      expect(StreakSnapshot.parseDayKey(null), isNull);
      expect(StreakSnapshot.parseDayKey('2026-03'), isNull);
      expect(StreakSnapshot.parseDayKey('a-b-c'), isNull);
    });

    test('labels', () {
      expect(const StreakSnapshot().label, 'اليوم الأول');
      expect(const StreakSnapshot(count: 1).label, 'اليوم الأول');
      expect(const StreakSnapshot(count: 5).label, '5 أيام متواصلة');
    });
  });

  group('currentCount', () {
    test('alive through yesterday, broken after a skipped day', () {
      final state = at(4, DateTime(2026, 9, 10));
      expect(StreakMath.currentCount(state, DateTime(2026, 9, 10, 20)), 4);
      expect(StreakMath.currentCount(state, DateTime(2026, 9, 11, 23)), 4);
      expect(StreakMath.currentCount(state, DateTime(2026, 9, 12)), 0);
      expect(
        StreakMath.currentCount(
          at(0, DateTime(2026, 9, 10)),
          DateTime(2026, 9, 10),
        ),
        0,
      );
      expect(
        StreakMath.currentCount(const StreakSnapshot(), DateTime(2026)),
        0,
      );
    });
  });

  group('record', () {
    test('keeps the earliest start date', () {
      final state = at(2, DateTime(2026, 9, 1), started: DateTime(2026, 1, 1));
      final next = StreakMath.record(state, DateTime(2026, 9, 2));
      expect(next.count, 3);
      expect(next.startedAt, DateTime(2026, 1, 1));
    });

    test('a zero count recorded again today becomes one', () {
      final next = StreakMath.record(
        at(0, DateTime(2026, 9, 2)),
        DateTime(2026, 9, 2),
      );
      expect(next.count, 1);
    });

    test('a last day in the future is treated as today', () {
      final next = StreakMath.record(
        at(3, DateTime(2026, 9, 5)),
        DateTime(2026, 9, 2),
      );
      expect(next.count, 3);
      expect(next.lastDay, DateTime(2026, 9, 2));
    });

    test('crosses month ends', () {
      final next = StreakMath.record(
        at(9, DateTime(2026, 2, 28)),
        DateTime(2026, 3, 1, 7),
      );
      expect(next.count, 10);
    });
  });

  group('merge', () {
    test('a remote without a day keeps local, earliest start wins', () {
      final merged = StreakMath.merge(
        at(3, DateTime(2026, 9, 3), started: DateTime(2026, 5)),
        at(0, null, started: DateTime(2026, 2)),
      );
      expect(merged.count, 3);
      expect(merged.lastDay, DateTime(2026, 9, 3));
      expect(merged.startedAt, DateTime(2026, 2));
    });

    test('a local without a day adopts the remote', () {
      final merged = StreakMath.merge(
        const StreakSnapshot(),
        at(0, DateTime(2026, 9, 3, 15)),
      );
      expect(merged.count, 1);
      expect(merged.lastDay, DateTime(2026, 9, 3));
    });

    test('same day keeps the larger count', () {
      final merged = StreakMath.merge(
        at(2, DateTime(2026, 9, 3)),
        at(6, DateTime(2026, 9, 3)),
      );
      expect(merged.count, 6);
    });

    test('the later day wins; a gap over one day does not extend', () {
      final merged = StreakMath.merge(
        at(9, DateTime(2026, 9, 1)),
        at(1, DateTime(2026, 9, 5)),
      );
      expect(merged.count, 1);
      expect(merged.lastDay, DateTime(2026, 9, 5));

      final remoteAhead = StreakMath.merge(
        at(1, DateTime(2026, 9, 1)),
        at(4, DateTime(2026, 9, 2)),
      );
      expect(remoteAhead.count, 4);
    });
  });

  test('differs compares count and days, not times', () {
    expect(
      StreakMath.differs(
        at(2, DateTime(2026, 9, 1, 8), started: DateTime(2026, 1, 1, 8)),
        at(2, DateTime(2026, 9, 1, 22), started: DateTime(2026, 1, 1, 20)),
      ),
      isFalse,
    );
    expect(
      StreakMath.differs(
        at(2, DateTime(2026, 9, 1)),
        at(3, DateTime(2026, 9, 1)),
      ),
      isTrue,
    );
    expect(
      StreakMath.differs(
        at(2, DateTime(2026, 9, 1)),
        at(2, DateTime(2026, 9, 2)),
      ),
      isTrue,
    );
    expect(
      StreakMath.differs(at(2, null), at(2, null, started: DateTime(2026))),
      isTrue,
    );
  });

  test('milestones', () {
    expect(nextStreakMilestone(0), 3);
    expect(nextStreakMilestone(7), 14);
    expect(nextStreakMilestone(100), 180);
    expect(nextStreakMilestone(364), 365);
    expect(nextStreakMilestone(800), 1095);
  });
}
