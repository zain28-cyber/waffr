// sync_mapper: model <-> /sync row conversion for every collection, the
// readers' validation and defaults, list helpers, and merge spot checks.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/app_notification.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/sync/sync_mapper.dart';
import 'package:waffr/core/sync/sync_merge.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';

void main() {
  test('income and expense stay transactions; savings become transfers', () {
    final income = WaffrTransaction(
      id: 'tx_income',
      type: TransactionType.income,
      amount: 100,
      dateTime: DateTime.utc(2026, 1, 1),
      frequency: RecurringFrequency.monthly,
    );
    final expense = WaffrTransaction(
      id: 'tx_expense',
      type: TransactionType.expense,
      amount: 20,
      dateTime: DateTime.utc(2026, 1, 2),
      category: 'طعام',
    );
    final saved = WaffrTransaction(
      id: 'tx_save',
      type: TransactionType.savingsIn,
      amount: 15,
      dateTime: DateTime.utc(2026, 1, 3),
      transferKind: SavingsTransferKind.manual,
      goalId: 'g1',
    );

    expect(transactionToSync(income)['type'], 'income');
    expect(transactionToSync(expense)['type'], 'expense');
    expect(transferToSync(saved)['direction'], 'to_savings');
    expect(transferToSync(saved)['goal_client_id'], 'g1');
  });

  test('round-trip keeps client ids', () {
    final goal = SavingsGoal(
      id: 'g99',
      name: 'سيارة',
      targetAmount: 500,
      createdAt: DateTime.utc(2026, 2, 1),
      duration: GoalDurationPreset.month,
    );
    final decoded = goalFromSync(goalToSync(goal));
    expect(decoded?.id, 'g99');
    expect(decoded?.targetAmount, 500);

    final recurring = RecurringExpense(
      id: 'r1',
      amount: 12.5,
      category: 'فواتير',
      paymentMethod: 'نقد',
      unit: RecurringUnit.month,
      intervalCount: 1,
      createdAt: DateTime.utc(2026, 3, 1),
      nextDueAt: DateTime.utc(2026, 4, 1),
      requiresConfirmation: true,
      remindAt: DateTime.utc(2026, 4, 3),
    );
    final recurringDecoded = recurringFromSync(recurringToSync(recurring));
    expect(recurringDecoded?.id, 'r1');
    expect(recurringDecoded?.amount, 12.5);
    expect(recurringDecoded?.requiresConfirmation, isTrue);
    expect(recurringDecoded?.remindAt?.toUtc(), DateTime.utc(2026, 4, 3));
    expect(recurringDecoded?.remindOnIncome, isFalse);

    final note = AppNotification(
      id: 'n1',
      type: NotificationType.goalReached,
      title: 'تم',
      message: 'وصل الهدف',
      createdAt: DateTime.utc(2026, 5, 1),
      eventKey: 'goalReached:g99',
    );
    final noteDecoded = notificationFromSync(notificationToSync(note));
    expect(noteDecoded?.id, 'n1');
    expect(noteDecoded?.eventKey, 'goalReached:g99');
  });

  test('last-write-wins keeps the newer local record', () {
    final older = WaffrTransaction(
      id: 'same',
      type: TransactionType.expense,
      amount: 10,
      dateTime: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final newer = WaffrTransaction(
      id: 'same',
      type: TransactionType.expense,
      amount: 11,
      dateTime: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    final items = [newer];
    final changed = mergeRemoteRecords<WaffrTransaction>(
      items: items,
      upserts: [older],
      deletes: const [],
      collection: SyncCollection.transactions,
      idOf: (item) => item.id,
      updatedOf: (item) => item.syncUpdatedAt,
    );
    expect(changed, isFalse);
    expect(items.single.amount, 11);
  });

  test('newer remote delete removes the local record', () {
    final local = WaffrTransaction(
      id: 'gone',
      type: TransactionType.expense,
      amount: 8,
      dateTime: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final items = [local];
    final changed = mergeRemoteRecords<WaffrTransaction>(
      items: items,
      upserts: const [],
      deletes: [
        SyncTombstone(clientId: 'gone', deletedAt: DateTime.utc(2026, 1, 3)),
      ],
      collection: SyncCollection.transactions,
      idOf: (item) => item.id,
      updatedOf: (item) => item.syncUpdatedAt,
    );
    expect(changed, isTrue);
    expect(items, isEmpty);
  });

  test('newerOrEqual treats equal timestamps as incoming wins', () {
    final stamp = DateTime.utc(2026, 6, 1, 12);
    expect(newerOrEqual(stamp, stamp), isTrue);
    expect(newerOrEqual(stamp.add(const Duration(seconds: 1)), stamp), isTrue);
    expect(newerOrEqual(stamp, stamp.add(const Duration(seconds: 1))), isFalse);
  });

  test('custom categories round-trip client ids and icons', () {
    final entry = CustomCategoryEntry(
      id: 'cat_1',
      label: 'قهوة',
      iconIndex: 2,
      updatedAt: DateTime.utc(2026, 3, 1),
    );
    final payload = categoryToSync(entry);
    expect(payload['client_id'], 'cat_1');
    expect(payload['icon_index'], 2);
    final restored = CustomCategoryEntry.fromSync(payload);
    expect(restored?.id, 'cat_1');
    expect(restored?.label, 'قهوة');
    expect(restored?.iconIndex, 2);
  });

  group('readers', () {
    test('parseMoney accepts numbers and numeric text only', () {
      expect(parseMoney(3), 3.0);
      expect(parseMoney('2.5'), 2.5);
      expect(parseMoney(' '), isNull);
      expect(parseMoney('abc'), isNull);
      expect(parseMoney(null), isNull);
    });

    test('transactionFromSync validates and fills defaults', () {
      expect(
        transactionFromSync({
          'client_id': 'a',
          'amount': '0',
          'occurred_at': '2026-01-01',
        }),
        isNull,
      );
      expect(
        transactionFromSync({'amount': '5', 'occurred_at': '2026-01-01'}),
        isNull,
      );
      expect(transactionFromSync({'client_id': 'a', 'amount': '5'}), isNull);

      final row = transactionFromSync({
        'client_id': 'a',
        'amount': '5',
        'type': 'weird',
        'occurred_at': '2026-01-01T00:00:00Z',
        'category': ' ',
        'currency_code': 'usd',
        'frequency': 'weekly',
        'period_key': 'w:2025-12-27',
      })!;
      expect(row.type, TransactionType.expense);
      expect(row.category, isNull);
      expect(row.currencyCode, 'USD');
      expect(row.frequency, RecurringFrequency.weekly);
      expect(row.periodKey, 'w:2025-12-27');
      expect(row.dateTime.toUtc(), DateTime.utc(2026));
      expect(row.updatedAt, isNull);
    });

    test('a full transaction round trip', () {
      final income = WaffrTransaction(
        id: 'i',
        type: TransactionType.income,
        amount: 99.5,
        currencyCode: 'EUR',
        dateTime: DateTime.utc(2026, 2, 2),
        note: 'راتب',
        sourceId: 'src',
        frequency: RecurringFrequency.monthly,
        periodKey: 'm:2026-02',
        updatedAt: DateTime.utc(2026, 2, 3),
      );
      final back = transactionFromSync(transactionToSync(income))!;
      expect(back.type, TransactionType.income);
      expect(back.amount, 99.5);
      expect(back.currencyCode, 'EUR');
      expect(back.note, 'راتب');
      expect(back.sourceId, 'src');
      expect(back.frequency, RecurringFrequency.monthly);
      expect(back.periodKey, 'm:2026-02');
      expect(back.updatedAt, DateTime.utc(2026, 2, 3));
    });

    test('transfers: direction, kind defaults and round trip', () {
      Map<String, dynamic> raw(Map<String, dynamic> extra) => {
        'client_id': 't',
        'amount': '10',
        'occurred_at': '2026-01-01T00:00:00Z',
        ...extra,
      };
      expect(transferFromSync(raw({}))!.type, TransactionType.savingsIn);
      expect(
        transferFromSync(raw({}))!.transferKind,
        SavingsTransferKind.manual,
      );
      final out = transferFromSync(raw({'direction': 'to_balance'}))!;
      expect(out.type, TransactionType.savingsOut);
      expect(out.transferKind, SavingsTransferKind.withdraw);
      expect(
        transferFromSync(raw({'kind': 'withdraw'}))!.type,
        TransactionType.savingsOut,
        reason: 'a withdraw kind wins over a missing direction',
      );
      expect(transferFromSync(raw({'amount': '-1'})), isNull);
      expect(transferFromSync(raw({'occurred_at': null})), isNull);

      final saved = WaffrTransaction(
        id: 's',
        type: TransactionType.savingsIn,
        amount: 5,
        dateTime: DateTime.utc(2026, 3, 1),
        transferKind: SavingsTransferKind.periodLeftover,
        goalId: 'g',
        processedPeriodKey: 'm:2026-02',
        note: 'n',
      );
      final back = transferFromSync(transferToSync(saved))!;
      expect(back.transferKind, SavingsTransferKind.periodLeftover);
      expect(back.goalId, 'g');
      expect(back.processedPeriodKey, 'm:2026-02');
      expect(back.note, 'n');
    });

    test('goal round trip keeps the plan fields', () {
      final goal = SavingsGoal(
        id: 'g',
        name: 'n',
        targetAmount: 300,
        currencyCode: 'USD',
        createdAt: DateTime.utc(2026),
        duration: GoalDurationPreset.threeMonths,
        completedAt: DateTime.utc(2026, 4),
        completedAmount: 310,
        allocatePercent: 12.5,
        allocateAmount: 100,
        deductFrequency: RecurringFrequency.weekly,
        isPeriodic: true,
        durationCount: 13,
        priority: 3,
        updatedAt: DateTime.utc(2026, 4, 2),
      );
      final row = goalToSync(goal);
      expect(row['target_amount'], '300.0');
      expect(row['deadline'], isNull);
      final back = goalFromSync(row)!;
      expect(back.currencyCode, 'USD');
      expect(back.completedAmount, 310);
      expect(back.allocatePercent, 12.5);
      expect(back.deductFrequency, RecurringFrequency.weekly);
      expect(back.durationCount, 13);
      expect(back.priority, 3);
      expect(back.isCompleted, isTrue);
      expect(goalFromSync({'client_id': 'x', 'name': 'y'}), isNull);
    });

    test('notification round trip keeps read state and metadata', () {
      final note = AppNotification(
        id: 'n',
        type: NotificationType.largeExpense,
        title: 't',
        message: 'm',
        createdAt: DateTime.utc(2026),
        eventKey: 'k',
        isRead: true,
        relatedId: 'e',
        metadata: const {'amount': '5'},
      );
      final back = notificationFromSync(notificationToSync(note))!;
      expect(back.type, NotificationType.largeExpense);
      expect(back.isRead, isTrue);
      expect(back.relatedId, 'e');
      expect(back.metadata, {'amount': '5'});
      expect(notificationFromSync({'client_id': 'x'}), isNull);
    });

    test('recurring rows without a positive amount are rejected', () {
      expect(recurringFromSync({'client_id': 'r', 'amount': '0'}), isNull);
    });
  });

  test('collection payload, default list and list helpers', () {
    final payload = collectionPayload(
      upserts: [
        {'a': 1},
      ],
      deletes: [SyncTombstone(clientId: 'x', deletedAt: DateTime.utc(2026))],
    );
    expect(payload['upserts'], [
      {'a': 1},
    ]);
    expect(payload['deletes'], [
      {'client_id': 'x', 'deleted_at': '2026-01-01T00:00:00.000Z'},
    ]);

    final list = shoppingListToSync();
    expect(list['client_id'], defaultShoppingListId);
    expect(list['name'], defaultShoppingListName);

    expect(asMapList('x'), isEmpty);
    expect(
      asMapList([
        {'a': 1},
        'junk',
        <Object, Object>{'b': 2},
      ]),
      [
        {'a': 1},
        {'b': 2},
      ],
    );
    expect(tombstonesFromSync('x'), isEmpty);
    expect(
      tombstonesFromSync([
        {'client_id': 'a'},
        {'client_id': ''},
        3,
      ]).map((t) => t.clientId),
      ['a'],
    );
  });
}
