// TransactionStore write side for single entries: adding expenses (balance
// checks, source-id dedupe), undoing expenses and incomes (with sync
// tombstones), manual saving and withdrawing, and listener notifications.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import '../../helpers/store_harness.dart';

void main() {
  final store = TransactionStore.instance;

  setUp(() async {
    await setUpStores();
  });

  Future<WaffrTransaction?> spend(
    double amount, {
    String? sourceId,
    DateTime? at,
    String? currencyCode,
  }) => store.addExpense(
    amount: amount,
    category: 'طعام',
    paymentMethod: 'نقداً',
    note: 'غداء',
    sourceId: sourceId,
    occurredAt: at,
    currencyCode: currencyCode,
  );

  group('addExpense', () {
    test('records an expense that fits the balance', () async {
      await store.addIncome(amount: 500);
      final at = DateTime.now().subtract(const Duration(days: 1));

      final expense = await spend(120, at: at);

      expect(expense, isNotNull);
      expect(expense!.amount, 120);
      expect(expense.category, 'طعام');
      expect(expense.paymentMethod, 'نقداً');
      expect(expense.note, 'غداء');
      expect(expense.currencyCode, 'SYP');
      expect(expense.dateTime, at);
      expect(store.expenses.single.id, expense.id);
      expect(store.balance, 380);
    });

    test('refuses an amount above the balance', () async {
      await store.addIncome(amount: 100);
      expect(await spend(100.5), isNull);
      expect(await spend(100), isNotNull);
      expect(await spend(0.01), isNull, reason: 'balance is now zero');
      expect(store.expenses, hasLength(1));
    });

    test('checks the balance of the expense currency', () async {
      await store.addIncome(amount: 1000);
      expect(await spend(10, currencyCode: 'USD'), isNull);
      await store.addIncome(amount: 20, currencyCode: 'USD');
      final usd = await spend(10, currencyCode: 'usd');
      expect(usd?.currencyCode, 'USD');
      expect(store.balanceFor('USD'), 10);
    });

    test('posts each source id once, even when called concurrently', () async {
      await store.addIncome(amount: 1000);
      final results = await Future.wait([
        spend(50, sourceId: 'shopping:1'),
        spend(50, sourceId: 'shopping:1'),
      ]);
      expect(results[0]!.id, results[1]!.id);
      expect(store.expenses, hasLength(1));

      final again = await spend(70, sourceId: 'shopping:1');
      expect(again!.amount, 50, reason: 'the saved one is returned');
      expect(store.expenses, hasLength(1));
    });
  });

  group('undo', () {
    test(
      'undoing an expense restores the balance and logs a tombstone',
      () async {
        await store.addIncome(amount: 300);
        final expense = (await spend(100))!;

        expect(await store.undoExpense(expense.id), isTrue);
        expect(store.expenses, isEmpty);
        expect(store.balance, 300);
        expect(
          SyncTombstones.instance
              .of(SyncCollection.transactions)
              .map((t) => t.clientId),
          [expense.id],
        );
        expect(await store.undoExpense(expense.id), isFalse);
      },
    );

    test('undo only matches the right row type', () async {
      await store.addIncome(amount: 300);
      final incomeId = store.incomes.single.id;
      final expense = (await spend(100))!;

      expect(await store.undoExpense(incomeId), isFalse);
      expect(await store.undoIncome(expense.id), isFalse);
      expect(await store.undoIncome('missing'), isFalse);

      expect(await store.undoIncome(incomeId), isTrue);
      expect(store.incomes, isEmpty);
      expect(store.balance, -100, reason: 'the expense stays');
    });
  });

  group('savings moves', () {
    test(
      'manual saving moves balance into savings and tags the top goal',
      () async {
        await store.addIncome(amount: 1000);
        await store.createGoal(
          name: 'سفر',
          targetAmount: 5000,
          duration: GoalDurationPreset.year,
        );
        final goalId = store.activeGoals.single.id;

        expect(await store.saveManually(0), isFalse);
        expect(await store.saveManually(1000.01), isFalse);
        expect(await store.saveManually(400), isTrue);

        final transfer = store.savingsTransfers.single;
        expect(transfer.isSavingsIn, isTrue);
        expect(transfer.transferKind, SavingsTransferKind.manual);
        expect(transfer.goalId, goalId);
        expect(transfer.note, 'توفير يدوي');
        expect(store.balance, 600);
        expect(store.savingsBalance, 400);
        expect(store.goalProgress(store.activeGoals.single), 400);
      },
    );

    test('withdrawing is limited to the savings balance', () async {
      await store.addIncome(amount: 1000);
      await store.saveManually(300);

      expect(await store.withdrawFromSavings(300.01), isFalse);
      expect(await store.withdrawFromSavings(-1), isFalse);
      expect(await store.withdrawFromSavings(100), isTrue);

      final out = store.savingsTransfers.first;
      expect(out.isSavingsOut, isTrue);
      expect(out.transferKind, SavingsTransferKind.withdraw);
      expect(store.savingsBalance, 200);
      expect(store.balance, 800);
    });
  });

  test('every change notifies listeners', () async {
    var calls = 0;
    void listener() => calls++;
    store.addListener(listener);
    addTearDown(() => store.removeListener(listener));

    await store.addIncome(amount: 100);
    final afterIncome = calls;
    expect(afterIncome, greaterThan(0));

    final expense = (await spend(10))!;
    expect(calls, greaterThan(afterIncome));
    final afterExpense = calls;

    await store.undoExpense(expense.id);
    expect(calls, greaterThan(afterExpense));
  });

  test('entries survive a reload from prefs', () async {
    await store.addIncome(amount: 900, source: 'راتب');
    await spend(100);
    await store.saveManually(200);

    resetStoreCaches();
    await store.ensureLoaded();

    expect(store.incomes.single.note, 'راتب');
    expect(store.expenses.single.amount, 100);
    expect(store.savingsBalance, 200);
    expect(store.balance, 600);
  });
}
