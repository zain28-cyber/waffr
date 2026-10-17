// NotificationService: the alert rules (balance, spending, goals, savings
// transfers, finished periods, large expenses) run through evaluate()
// against the saved snapshot, plus the feed itself: dedupe, mute, read
// state, removal with tombstones, persistence and the remote merge.
//
// Device notifications are mirrored through SystemNotifications, which
// finds no plugin in tests and does nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/sync/sync_mapper.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/models/app_notification.dart';
import 'package:waffr/data/models/calendar_period.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import '../../helpers/ledger_builders.dart';
import '../../helpers/store_harness.dart';

void main() {
  final service = NotificationService.instance;
  final store = TransactionStore.instance;
  late SharedPreferences prefs;

  setUp(() async {
    prefs = await setUpStores();
  });

  Future<void> spend(double amount) async {
    final added = await store.addExpense(
      amount: amount,
      category: 'طعام',
      paymentMethod: 'نقداً',
    );
    expect(added, isNotNull);
  }

  List<NotificationType> types() =>
      service.notifications.map((n) => n.type).toList();

  group('evaluate', () {
    test('the first run only records a baseline', () async {
      await store.addIncome(amount: 1000);
      await spend(900);
      await service.evaluate();
      expect(service.notifications, isEmpty);
    });

    test(
      'balance and spending alerts fire once when a level is crossed',
      () async {
        await store.addIncome(amount: 1000);
        await service.evaluate();

        await spend(800);
        await service.evaluate();
        expect(
          types(),
          unorderedEquals([
            NotificationType.balanceWarning,
            NotificationType.highSpending,
          ]),
        );
        final warning = service.notifications.firstWhere(
          (n) => n.type == NotificationType.balanceWarning,
        );
        expect(warning.title, 'بقي ربع رصيدك');
        expect(warning.message, contains('200 ل.س'));
        expect(warning.message, contains('1,000 ل.س'));
        expect(warning.metadata['percent'], '25');

        final spending = service.notifications.firstWhere(
          (n) => n.type == NotificationType.highSpending,
        );
        expect(spending.title, contains('50%'));

        await service.evaluate();
        expect(service.notifications, hasLength(2), reason: 'no repeats');

        await spend(150);
        await service.evaluate();
        expect(service.notifications, hasLength(3));
        expect(service.notifications.first.title, 'رصيدك على وشك النفاد');
      },
    );

    test(
      'dropping through two levels at once sends only the lower one',
      () async {
        await store.addIncome(amount: 1000);
        await service.evaluate();
        await spend(950);
        await service.evaluate();
        final warnings = service.notifications
            .where((n) => n.type == NotificationType.balanceWarning)
            .toList();
        expect(warnings.single.metadata['percent'], '10');
      },
    );

    test('goal progress and completion are announced', () async {
      await store.addIncome(amount: 5000);
      await store.createGoal(
        name: 'سفر',
        targetAmount: 1000,
        duration: GoalDurationPreset.year,
      );
      await service.evaluate();

      await store.saveManually(600);
      await service.evaluate();
      final half = service.notifications.single;
      expect(half.type, NotificationType.goalProgress);
      expect(half.title, contains('«سفر»'));
      expect(half.metadata['percent'], '50');

      await store.saveManually(200);
      await service.evaluate();
      expect(service.notifications.first.metadata['percent'], '75');

      await store.saveManually(200);
      await service.evaluate();
      final reached = service.notifications.firstWhere(
        (n) => n.type == NotificationType.goalReached,
      );
      expect(reached.title, 'اكتمل هدف «سفر»');
      expect(reached.relatedId, store.goals.single.id);
    });

    test('goals completed before the baseline are not announced', () async {
      await store.addIncome(amount: 5000);
      await store.createGoal(
        name: 'قديم',
        targetAmount: 100,
        duration: GoalDurationPreset.month,
      );
      await store.saveManually(100);
      await service.evaluate();
      await service.evaluate();
      expect(service.notifications, isEmpty);
    });

    test('an expense twice the earlier average is flagged', () async {
      await store.addIncome(amount: 10000);
      for (var i = 0; i < 4; i++) {
        await spend(10);
      }
      await service.evaluate();

      await spend(100);
      await service.evaluate();
      final large = service.notifications.single;
      expect(large.type, NotificationType.largeExpense);
      expect(large.message, contains('100 ل.س'));
      expect(large.message, contains('الطعام'));
    });

    test('a period leftover moved to savings is announced', () async {
      await service.seedIfNeeded();
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 3);
      final key = CalendarPeriod.monthlyKey(lastMonth);
      await prefs.setStringList(TransactionStore.transactionsKey, [
        incomeAt(
          1000,
          lastMonth,
          frequency: RecurringFrequency.monthly,
          periodKey: key,
        ).encode(),
        expenseAt(300, lastMonth).encode(),
      ]);
      store.resetCache();
      await store.ensureLoaded();
      await service.evaluate();

      final note = service.notifications.firstWhere(
        (n) => n.type == NotificationType.savingsTransferred,
      );
      expect(note.title, 'أُضيف 700 ل.س إلى التوفير');
      expect(note.metadata['periodType'], 'monthly');
      expect(note.metadata['periodKey'], key);
    });

    test('a fully spent period says nothing was saved', () async {
      await service.seedIfNeeded();
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));
      final key = CalendarPeriod.weeklyKey(lastWeek);
      await prefs.setStringList(TransactionStore.transactionsKey, [
        incomeAt(
          100,
          lastWeek,
          frequency: RecurringFrequency.weekly,
          periodKey: key,
        ).encode(),
        expenseAt(100, lastWeek).encode(),
      ]);
      store.resetCache();
      await store.ensureLoaded();
      await service.evaluate();

      final note = service.notifications.firstWhere(
        (n) => n.type == NotificationType.recurringPeriodCompleted,
      );
      expect(note.title, 'انتهى الأسبوع دون توفير');
      expect(note.metadata['periodType'], 'weekly');
    });

    test('the snapshot survives a restart, so alerts do not repeat', () async {
      await store.addIncome(amount: 1000);
      await service.evaluate();
      await spend(800);
      await service.evaluate();
      expect(service.notifications, hasLength(2));

      service.resetCache();
      await service.evaluate();
      expect(service.notifications, hasLength(2));
    });
  });

  group('feed', () {
    Future<bool> add(String key) => service.add(
      type: NotificationType.recurringExpenseApplied,
      title: 'عنوان $key',
      message: 'نص',
      eventKey: key,
    );

    test('event keys are written once', () async {
      expect(await add('k1'), isTrue);
      expect(await add('k1'), isFalse);
      expect(service.notifications, hasLength(1));
      expect(service.unreadCount, 1);
    });

    test('muted alerts are swallowed for good', () async {
      await service.setMuted(true);
      expect(service.isMuted, isTrue);
      expect(await add('quiet'), isFalse);
      await service.toggleMuted();
      expect(service.isMuted, isFalse);
      expect(await add('quiet'), isFalse, reason: 'the key was claimed');
      expect(await add('loud'), isTrue);
    });

    test('read state, removal and clearing', () async {
      await add('a');
      await add('b');
      await add('c');
      final ids = service.notifications.map((n) => n.id).toList();

      await service.markRead(ids.first);
      expect(service.unreadCount, 2);
      await service.markAllRead();
      expect(service.unreadCount, 0);

      await service.remove(ids.first);
      await service.remove('missing');
      expect(service.notifications, hasLength(2));
      await service.clearHistory();
      expect(service.notifications, isEmpty);
      expect(
        SyncTombstones.instance
            .of(SyncCollection.notifications)
            .map((t) => t.clientId),
        unorderedEquals(ids),
      );
    });

    test('the feed, keys and mute survive a reload', () async {
      await add('a');
      await service.setMuted(true);
      service.resetCache();
      await service.ensureLoaded();
      expect(service.notifications.single.eventKey, 'a');
      expect(service.isMuted, isTrue);
      await service.setMuted(false);
      expect(await add('a'), isFalse);
    });

    test('newest first', () async {
      await service.add(
        type: NotificationType.goalReached,
        title: 'قديم',
        message: '',
        eventKey: 'old',
        createdAt: DateTime(2020),
      );
      await add('new');
      expect(service.notifications.first.eventKey, 'new');
    });
  });

  test('applyRemoteSync merges rows, claims their keys and the mute', () async {
    final remote = AppNotification(
      id: 'srv1',
      type: NotificationType.goalReached,
      title: 'من الخادم',
      message: 'نص',
      createdAt: DateTime(2026, 5, 1),
      eventKey: 'goalReached:g9',
      updatedAt: DateTime.utc(2026, 5, 1),
    );
    await service.applyRemoteSync(
      upserts: [notificationToSync(remote)],
      deletes: const [],
      muted: true,
    );
    expect(service.notifications.single.id, 'srv1');
    expect(service.isMuted, isTrue);

    await service.setMuted(false);
    expect(
      await service.add(
        type: NotificationType.goalReached,
        title: 'x',
        message: 'y',
        eventKey: 'goalReached:g9',
      ),
      isFalse,
    );

    await service.applyRemoteSync(
      upserts: const [],
      deletes: [SyncTombstone(clientId: 'srv1', deletedAt: DateTime.utc(2027))],
    );
    expect(service.notifications, isEmpty);
  });
}
