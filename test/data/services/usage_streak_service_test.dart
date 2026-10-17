// UsageStreakService: recording days, the one-time increase, broken
// streaks, the unsynced flag, remote merges and the sync fields; plus the
// pure streak, duration and spending-comparison helpers it relies on.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/usage/streak_math.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/usage/usage_duration.dart';
import 'package:waffr/core/insights/spending_improvement.dart';
import 'package:waffr/data/models/transaction.dart';

import '../../helpers/store_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => UsageStreakService.clock = DateTime.now);

  test('opening on the next day hands out one streak increase', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.instance;
    await prefs.clear();
    TransactionStore.instance.resetCache();
    final service = UsageStreakService.instance..resetCache();

    await service.recordToday(now: DateTime(2026, 9, 1, 9));
    expect(
      service.takeIncrease(),
      isNull,
      reason: 'day one is not an increase',
    );

    await service.recordToday(now: DateTime(2026, 9, 1, 20));
    expect(service.takeIncrease(), isNull, reason: 'same day again');

    await service.recordToday(now: DateTime(2026, 9, 2, 8));
    final increase = service.takeIncrease();
    expect(increase?.from, 1);
    expect(increase?.to, 2);
    expect(service.takeIncrease(), isNull, reason: 'handed out once');

    UsageStreakService.clock = () => DateTime(2026, 9, 5, 8);
    await service.recordToday();
    expect(service.count, 1);
    expect(service.takeIncrease(), isNull, reason: 'a broken streak restarts');
  });

  test('a skipped day reads as a broken streak before the next open', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.instance;
    await prefs.clear();
    TransactionStore.instance.resetCache();
    final service = UsageStreakService.instance..resetCache();

    UsageStreakService.clock = () => DateTime(2026, 9, 1, 9);
    await service.recordToday();
    UsageStreakService.clock = () => DateTime(2026, 9, 2, 9);
    await service.recordToday();
    expect(service.count, 2);

    // Next day, not opened yet: still alive.
    UsageStreakService.clock = () => DateTime(2026, 9, 3, 23);
    expect(service.count, 2);

    // A whole day skipped: broken, and day one again on the next open.
    UsageStreakService.clock = () => DateTime(2026, 9, 4, 8);
    expect(service.count, 0);
    expect(service.label, 'اليوم الأول');
    await service.recordToday();
    expect(service.count, 1);
  });

  test('a streak change stays unsynced until a sync carried it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.instance;
    await prefs.clear();
    TransactionStore.instance.resetCache();
    final service = UsageStreakService.instance..resetCache();
    UsageStreakService.clock = () => DateTime(2026, 9, 1, 9);

    await service.recordToday();
    expect(service.hasUnsyncedChange, isTrue);

    // A sync started, then the streak changed before it finished.
    final sent = service.revision;
    UsageStreakService.clock = () => DateTime(2026, 9, 2, 9);
    await service.recordToday();
    expect(await service.markSynced(sent), isTrue);
    expect(prefs.getBool(UsageStreakService.unsyncedKey), isTrue);

    expect(await service.markSynced(service.revision), isFalse);
    expect(prefs.getBool(UsageStreakService.unsyncedKey), isFalse);

    // The flag survives a restart.
    service.resetCache();
    await service.ensureLoaded();
    expect(service.hasUnsyncedChange, isFalse);
  });

  test('the next streak milestone is the next round number', () {
    expect(nextStreakMilestone(1), 3);
    expect(nextStreakMilestone(3), 7);
    expect(nextStreakMilestone(29), 30);
    expect(nextStreakMilestone(365), 730);
  });

  test('first open is day one and a repeat the same day stays there', () {
    final first = StreakMath.record(
      const StreakSnapshot(),
      DateTime(2026, 9, 1, 8),
    );
    expect(first.count, 1);
    expect(first.label, 'اليوم الأول');

    final again = StreakMath.record(first, DateTime(2026, 9, 1, 22));
    expect(again.count, 1);
    expect(again.label, 'اليوم الأول');
  });

  test('the next calendar day continues and a missed day restarts', () {
    final dayOne = StreakMath.record(
      const StreakSnapshot(),
      DateTime(2026, 9, 1),
    );
    final dayTwo = StreakMath.record(dayOne, DateTime(2026, 9, 2, 1));
    expect(dayTwo.count, 2);
    expect(dayTwo.label, '2 أيام متواصلة');

    final daySeven = StreakSnapshot(
      count: 7,
      lastDay: DateTime(2026, 9, 7),
      startedAt: DateTime(2026, 9, 1),
    );
    final missed = StreakMath.record(daySeven, DateTime(2026, 9, 9));
    expect(missed.count, 1);
    expect(missed.label, 'اليوم الأول');
  });

  test('merge keeps a longer streak when this device only recorded today', () {
    final local = StreakSnapshot(
      count: 1,
      lastDay: DateTime(2026, 9, 8),
      startedAt: DateTime(2026, 9, 8),
    );
    final remote = StreakSnapshot(
      count: 7,
      lastDay: DateTime(2026, 9, 7),
      startedAt: DateTime(2026, 6, 1),
    );
    final merged = StreakMath.merge(local, remote);
    expect(merged.count, 8);
    expect(StreakSnapshot.dayKey(merged.lastDay), '2026-09-08');
    expect(merged.startedAt, DateTime(2026, 6, 1));
  });

  test('usage duration stays compact', () {
    expect(
      usageDurationText(DateTime(2026, 9, 27), DateTime(2026, 9, 27, 18)),
      'اليوم',
    );
    expect(
      usageDurationText(DateTime(2026, 9, 20), DateTime(2026, 9, 27)),
      '7 أيام',
    );
  });

  test('spending improvement matches the reports comparison', () {
    final better = SpendingImprovement.calculate(
      currentTotal: 80,
      previousTotal: 100,
    );
    expect(better.kind, SpendingChange.positive);
    expect(better.text, '+20.0%');

    final worse = SpendingImprovement.calculate(
      currentTotal: 150,
      previousTotal: 100,
    );
    expect(worse.kind, SpendingChange.negative);
    expect(worse.detail, 'المصروف ارتفع مقارنة بالفترة السابقة');
  });

  group('sync', () {
    setUp(() async {
      await setUpStores();
    });

    test('syncFields carries the streak once a day was recorded', () async {
      final service = UsageStreakService.instance;
      await service.ensureLoaded();
      expect(service.syncFields(), isEmpty);

      await service.recordToday(now: DateTime(2026, 9, 1, 9));
      final fields = service.syncFields();
      expect(fields['streak_count'], 1);
      expect(fields['streak_last_date'], '2026-09-01');
      expect(fields['usage_started_at'], isNotNull);
    });

    test('a remote streak that is ahead is adopted', () async {
      final service = UsageStreakService.instance;
      UsageStreakService.clock = () => DateTime(2026, 9, 8, 10);
      await service.recordToday();
      await service.markSynced(service.revision);

      await service.applyRemote({
        'streak_count': 7,
        'streak_last_date': '2026-09-07',
        'usage_started_at': '2026-06-01T00:00:00Z',
      });
      expect(service.count, 8);
      expect(service.lastDay, DateTime(2026, 9, 8));
      expect(service.startedAt!.toUtc(), DateTime.utc(2026, 6, 1));
      expect(
        service.hasUnsyncedChange,
        isTrue,
        reason: 'the server is behind the merged streak',
      );
    });

    test('an empty remote streak changes nothing', () async {
      final service = UsageStreakService.instance;
      await service.recordToday(now: DateTime(2026, 9, 1));
      final before = service.revision;
      await service.applyRemote({'streak_count': 0});
      expect(service.revision, before);
      expect(service.lastDay, DateTime(2026, 9, 1));
    });

    test('the first record starts usage at the oldest ledger row', () async {
      await TransactionStore.instance.addIncome(amount: 5);
      final prefs = await AppPrefs.instance;
      await prefs.setStringList(TransactionStore.transactionsKey, [
        WaffrTransaction(
          id: 'old',
          type: TransactionType.income,
          amount: 5,
          dateTime: DateTime(2025, 3, 3),
        ).encode(),
      ]);
      resetStoreCaches();
      final state = await UsageStreakService.instance.recordToday(
        now: DateTime(2026, 9, 1),
      );
      expect(state.startedAt, DateTime(2025, 3, 3));
    });

    test('the streak survives a reload', () async {
      final service = UsageStreakService.instance;
      await service.recordToday(now: DateTime(2026, 9, 1));
      await service.recordToday(now: DateTime(2026, 9, 2));
      service.resetCache();
      UsageStreakService.clock = () => DateTime(2026, 9, 2, 20);
      await service.ensureLoaded();
      expect(service.count, 2);
      expect(service.label, '2 أيام متواصلة');
    });
  });
}
