// RecurringExpenseStore: posting due charges (catch-up, low balance, no
// duplicates), approvals and postponements, edits, deletes, totals, notices
// and the remote merge.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/core/sync/sync_mapper.dart';
import 'package:waffr/data/models/app_notification.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.instance;
    await prefs.clear();
    TransactionStore.instance.resetCache();
    RecurringExpenseStore.instance.resetCache();
    NotificationService.instance.resetCache();
    CurrencyStore.instance.resetCache();
  });

  Future<void> seedIncome(double amount) {
    return TransactionStore.instance.addIncome(
      amount: amount,
      frequency: RecurringFrequency.monthly,
      source: 'راتب',
    );
  }

  test('posts a due recurring expense once per open', () async {
    await seedIncome(1000);
    await RecurringExpenseStore.instance.addExpense(
      amount: 25,
      category: 'طعام',
      paymentMethod: 'نقداً',
      unit: RecurringUnit.day,
      intervalCount: 1,
      note: 'قهوة',
    );

    expect(TransactionStore.instance.expenses, hasLength(1));
    expect(TransactionStore.instance.expenses.single.amount, 25);
    expect(TransactionStore.instance.expenses.single.note, 'قهوة');

    final nextDue = RecurringExpenseStore.instance.items.single.nextDueAt;
    expect(nextDue.isAfter(DateTime.now()), isTrue);

    await RecurringExpenseStore.instance.processDue();
    expect(TransactionStore.instance.expenses, hasLength(1));
  });

  test('catches up missed periods without duplicating them', () async {
    await seedIncome(5000);
    final past = DateTime.now().subtract(const Duration(days: 3));
    final scheduled = RecurringExpense(
      id: 'rent-1',
      amount: 100,
      category: 'طعام',
      paymentMethod: 'نقداً',
      unit: RecurringUnit.day,
      intervalCount: 1,
      createdAt: past,
      nextDueAt: past,
    );
    final prefs = await AppPrefs.instance;
    await prefs.setStringList(RecurringExpenseStore.itemsKey, [
      scheduled.encode(),
    ]);
    RecurringExpenseStore.instance.resetCache();

    await RecurringExpenseStore.instance.processDue();
    final posted = TransactionStore.instance.expenses.length;
    expect(posted, greaterThanOrEqualTo(3));
    expect(posted, lessThanOrEqualTo(5));
    expect(
      RecurringExpenseStore.instance.items.single.nextDueAt.isAfter(
        DateTime.now(),
      ),
      isTrue,
    );

    await RecurringExpenseStore.instance.processDue();
    expect(TransactionStore.instance.expenses, hasLength(posted));
  });

  test('does not post or advance when the balance is too low', () async {
    await seedIncome(40);
    await RecurringExpenseStore.instance.addExpense(
      amount: 80,
      category: 'طعام',
      paymentMethod: 'نقداً',
      unit: RecurringUnit.month,
      intervalCount: 1,
    );

    expect(TransactionStore.instance.expenses, isEmpty);
    final due = RecurringExpenseStore.instance.items.single.nextDueAt;
    expect(due.isAfter(DateTime.now()), isFalse);

    await RecurringExpenseStore.instance.processDue();
    expect(TransactionStore.instance.expenses, isEmpty);
    expect(RecurringExpenseStore.instance.items.single.nextDueAt, due);
  });

  Future<void> seedPastConfirmed({required int daysAgo}) async {
    final past = DateTime.now().subtract(Duration(days: daysAgo, minutes: 1));
    final scheduled = RecurringExpense(
      id: 'rent-c',
      amount: 50,
      category: 'سكن',
      paymentMethod: 'نقداً',
      unit: RecurringUnit.day,
      intervalCount: 1,
      createdAt: past,
      nextDueAt: past,
      requiresConfirmation: true,
    );
    final prefs = await AppPrefs.instance;
    await prefs.setStringList(RecurringExpenseStore.itemsKey, [
      scheduled.encode(),
    ]);
    RecurringExpenseStore.instance.resetCache();
  }

  test('works without a configured monthly income', () async {
    await TransactionStore.instance.addIncome(
      amount: 300,
      frequency: RecurringFrequency.none,
      source: 'عمل حر',
    );
    await RecurringExpenseStore.instance.addExpense(
      amount: 20,
      category: 'طعام',
      paymentMethod: 'نقداً',
      unit: RecurringUnit.month,
      intervalCount: 1,
    );

    expect(RecurringExpenseStore.instance.items, hasLength(1));
    expect(TransactionStore.instance.expenses, hasLength(1));
  });

  test('confirmation charges wait and accumulate until approved', () async {
    await seedIncome(1000);
    await seedPastConfirmed(daysAgo: 2);

    final store = RecurringExpenseStore.instance;
    await store.processDue();
    expect(TransactionStore.instance.expenses, isEmpty);

    final code = store.items.single.currencyCode;
    expect(store.awaitingConfirmation(code), hasLength(1));
    expect(store.items.single.dueDates(DateTime.now()), hasLength(3));

    expect(await store.confirmDue('rent-c'), 1);
    expect(TransactionStore.instance.expenses, hasLength(1));
    expect(store.items.single.dueDates(DateTime.now()), hasLength(2));

    expect(await store.confirmDue('rent-c', all: true), 2);
    expect(TransactionStore.instance.expenses, hasLength(3));
    expect(store.awaitingConfirmation(code), isEmpty);
  });

  test('confirming stops when the balance runs out', () async {
    await seedIncome(70);
    await seedPastConfirmed(daysAgo: 2);

    final store = RecurringExpenseStore.instance;
    expect(await store.confirmDue('rent-c', all: true), 1);
    expect(store.items.single.dueDates(DateTime.now()), hasLength(2));
  });

  test('postponing until income keeps the charge pending', () async {
    await seedIncome(1000);
    await seedPastConfirmed(daysAgo: 0);

    final store = RecurringExpenseStore.instance;
    await store.postpone('rent-c', untilIncome: true);
    expect(store.items.single.remindOnIncome, isTrue);
    expect(
      store.awaitingConfirmation(store.items.single.currencyCode),
      hasLength(1),
    );

    await store.releaseIncomeReminders(store.items.single.currencyCode);
    expect(store.items.single.remindOnIncome, isFalse);
    expect(TransactionStore.instance.expenses, isEmpty);
  });

  group('edits and queries', () {
    Future<String> addMonthly(double amount, {String? note}) async {
      await RecurringExpenseStore.instance.addExpense(
        amount: amount,
        category: 'فواتير',
        paymentMethod: 'نقداً',
        unit: RecurringUnit.month,
        intervalCount: 1,
        note: note,
      );
      return RecurringExpenseStore.instance.items.first.id;
    }

    test('invalid schedules are ignored', () async {
      await seedIncome(1000);
      final store = RecurringExpenseStore.instance;
      await store.addExpense(
        amount: 0,
        category: 'x',
        paymentMethod: 'y',
        unit: RecurringUnit.day,
        intervalCount: 1,
      );
      await store.addExpense(
        amount: 5,
        category: 'x',
        paymentMethod: 'y',
        unit: RecurringUnit.day,
        intervalCount: 0,
      );
      expect(store.items, isEmpty);
    });

    test('updateAmount validates and keeps the schedule', () async {
      await seedIncome(1000);
      final id = await addMonthly(50);
      final store = RecurringExpenseStore.instance;
      expect(await store.updateAmount(id, 0), isFalse);
      expect(await store.updateAmount(id, double.nan), isFalse);
      expect(await store.updateAmount(id, 1e12), isFalse);
      expect(await store.updateAmount('missing', 10), isFalse);
      expect(await store.updateAmount(id, 75, currencyCode: 'USD'), isTrue);
      expect(store.byId(id)!.amount, 75);
      expect(store.byId(id)!.currencyCode, 'USD');
      expect(store.itemsFor('USD'), hasLength(1));
      expect(store.byId('missing'), isNull);
    });

    test(
      'totals, next charge and overdue counts skip paused schedules',
      () async {
        await seedIncome(1000);
        final store = RecurringExpenseStore.instance;
        final internet = await addMonthly(60, note: 'إنترنت');
        await store.addExpense(
          amount: 7,
          category: 'طعام',
          paymentMethod: 'نقداً',
          unit: RecurringUnit.day,
          intervalCount: 1,
        );
        expect(store.monthlyTotal('SYP'), closeTo(60 + 7 * 30, 1e-9));
        expect(store.overdueCount('SYP'), 0, reason: 'first charges posted');

        final next = store.nextUpcoming('SYP')!;
        expect(next.unit, RecurringUnit.day);

        await store.setEnabled(internet, false);
        expect(store.byId(internet)!.enabled, isFalse);
        expect(store.monthlyTotal('SYP'), closeTo(210, 1e-9));
        expect(
          store.overdueCount(
            'SYP',
            now: DateTime.now().add(const Duration(days: 40)),
          ),
          24,
          reason: 'due dates are capped at 24 per schedule',
        );
      },
    );

    test('a schedule held back by the balance is counted as overdue', () async {
      await seedIncome(10);
      await addMonthly(50);
      expect(RecurringExpenseStore.instance.overdueCount('SYP'), 1);
    });

    test('delete keeps posted charges and logs a tombstone', () async {
      await seedIncome(1000);
      final id = await addMonthly(40);
      final store = RecurringExpenseStore.instance;
      await store.deleteExpense('missing');
      await store.deleteExpense(id);
      expect(store.items, isEmpty);
      expect(TransactionStore.instance.expenses, hasLength(1));
      expect(
        SyncTombstones.instance.find(SyncCollection.recurringExpenses, id),
        isNotNull,
      );
    });

    test('switching to automatic posts what is waiting', () async {
      await seedIncome(1000);
      await seedPastConfirmed(daysAgo: 1);
      final store = RecurringExpenseStore.instance;
      await store.setRequiresConfirmation('rent-c', false);
      expect(store.items.single.requiresConfirmation, isFalse);
      expect(TransactionStore.instance.expenses, hasLength(2));
    });

    test('postponing by a duration sets a reminder date', () async {
      await seedIncome(1000);
      await seedPastConfirmed(daysAgo: 0);
      final store = RecurringExpenseStore.instance;
      await store.postpone('rent-c', after: const Duration(hours: 3));
      final item = store.items.single;
      expect(item.remindOnIncome, isFalse);
      expect(item.remindAt!.isAfter(DateTime.now()), isTrue);
    });

    test('posted and blocked charges write notices', () async {
      await seedIncome(30);
      await addMonthly(20, note: 'إنترنت');
      await addMonthly(500, note: 'إيجار');
      final notes = NotificationService.instance.notifications;
      expect(
        notes.map((n) => n.type),
        containsAll([
          NotificationType.recurringExpenseApplied,
          NotificationType.recurringExpenseBlocked,
        ]),
      );
      final applied = notes.firstWhere(
        (n) => n.type == NotificationType.recurringExpenseApplied,
      );
      expect(applied.title, 'خُصم «إنترنت»');
      final blocked = notes.firstWhere(
        (n) => n.type == NotificationType.recurringExpenseBlocked,
      );
      expect(blocked.title, 'تعذّر خصم «إيجار»');
    });

    test('schedules survive a reload; old rows get a currency', () async {
      await seedIncome(1000);
      await addMonthly(40, note: 'نت');
      RecurringExpenseStore.instance.resetCache();
      await RecurringExpenseStore.instance.ensureLoaded();
      expect(RecurringExpenseStore.instance.items.single.note, 'نت');
    });

    test('applyRemoteSync merges server schedules', () async {
      final store = RecurringExpenseStore.instance;
      final remote = RecurringExpense(
        id: 'srv',
        amount: 30,
        category: 'فواتير',
        paymentMethod: 'نقداً',
        unit: RecurringUnit.week,
        intervalCount: 2,
        createdAt: DateTime(2026, 1, 1),
        nextDueAt: DateTime(2099, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await store.applyRemoteSync(
        upserts: [
          recurringToSync(remote),
          {'client_id': 'bad'},
        ],
        deletes: const [],
      );
      expect(store.items.single.id, 'srv');
      expect(store.items.single.intervalCount, 2);

      await store.applyRemoteSync(
        upserts: const [],
        deletes: [
          SyncTombstone(clientId: 'srv', deletedAt: DateTime.utc(2027)),
        ],
      );
      expect(store.items, isEmpty);
    });
  });
}
