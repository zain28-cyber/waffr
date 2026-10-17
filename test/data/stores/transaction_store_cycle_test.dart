// TransactionStore balance cycle: when a cycle starts (income on an empty
// balance, carry-over, the 1st for monthly income), cycle spending, the
// cycle's 100% and the remaining ratio.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = TransactionStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.instance;
    await prefs.clear();
    store.resetCache();
    NotificationService.instance.resetCache();
    CurrencyStore.instance.resetCache();
  });

  Future<void> spend(double amount, {DateTime? at}) async {
    await store.addExpense(
      amount: amount,
      category: 'طعام',
      paymentMethod: 'نقداً',
      occurredAt: at,
    );
  }

  test('moving the leftover to savings resets the counter', () async {
    await store.addIncome(amount: 1000);
    await spend(400);
    expect(store.remainingRatio, closeTo(0.6, 1e-9));

    await store.addIncome(amount: 500, moveBalanceToSavings: true);

    expect(store.balance, 500);
    expect(store.maxBalance, 500);
    expect(store.cycleSpent, 0);
    expect(store.remainingRatio, 1);
  });

  test('new income on a fully spent balance resets the counter', () async {
    await store.addIncome(amount: 1000);
    await spend(1000);

    await store.addIncome(amount: 300, moveBalanceToSavings: true);

    expect(store.maxBalance, 300);
    expect(store.remainingRatio, 1);
  });

  test('new income kept with the leftover extends the same cycle', () async {
    await store.addIncome(amount: 1000);
    await spend(200);

    await store.addIncome(amount: 500);

    expect(store.balance, 1300);
    expect(store.maxBalance, 1500);
    expect(store.cycleSpent, 200);
  });

  test('monthly income starts a new cycle every month', () async {
    await store.addIncome(amount: 1000, frequency: RecurringFrequency.monthly);
    final now = DateTime.now();
    await spend(
      300,
      at: DateTime(now.year, now.month).subtract(const Duration(days: 2)),
    );

    expect(store.cycleSpent, 0);
    expect(store.remainingRatio, 1);

    await spend(100);
    expect(store.cycleSpent, 100);
    expect(store.maxBalance, 700);
  });

  test('an empty ledger has no 100% and a zero ratio', () async {
    await store.ensureLoaded();
    expect(store.maxBalance, 0);
    expect(store.remainingRatio, 0);
    expect(store.cycleSpent, 0);
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month);
    expect(
      store.cycleStartFor('SYP'),
      monthStart,
      reason: 'the cadence defaults to monthly',
    );
    expect(store.cycleKey, '${monthStart.millisecondsSinceEpoch}');
  });

  test('savings moves inside a cycle count toward its 100%', () async {
    await store.addIncome(amount: 1000);
    await store.saveManually(300);
    await store.withdrawFromSavings(100);
    expect(store.balance, 800);
    expect(store.maxBalance, 1000);
    expect(store.remainingRatio, closeTo(0.8, 1e-9));
  });

  test('each currency has its own cycle', () async {
    await store.addIncome(amount: 1000);
    await store.addIncome(amount: 40, currencyCode: 'USD');
    await spend(500);
    expect(store.remainingRatioFor('USD'), 1);
    expect(store.maxBalanceFor('USD'), 40);
    expect(store.remainingRatioFor('SYP'), closeTo(0.5, 1e-9));
  });
}
