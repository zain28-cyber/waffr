// Profile wallet health: the backdrop band follows real saving and a later
// withdrawal.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/insights/smart/smart_facts_loader.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/screens/offline/profile/profile_screen.dart';
import 'package:waffr/screens/offline/profile/wallet_backdrop.dart';

void main() {
  Future<void> refreshHealth(WidgetTester tester) async {
    // Timer-based coalescing can schedule another read while stores hydrate.
    // Flush both the fake timer queue and cached futures from the real zone.
    for (var pass = 0; pass < 4; pass++) {
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(() => SmartFactsLoader.load());
    }
    await tester.pumpAndSettle();
  }

  testWidgets('profile wallet reflects real saving and a later withdrawal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.instance;
    await prefs.clear();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final records = [
      WaffrTransaction(
        id: 'income',
        type: TransactionType.income,
        amount: 1000,
        dateTime: today.subtract(const Duration(days: 19)),
      ),
      for (var day = 0; day < 20; day++)
        WaffrTransaction(
          id: 'expense-$day',
          type: TransactionType.expense,
          amount: 30,
          dateTime: today.subtract(Duration(days: day)),
        ),
      WaffrTransaction(
        id: 'saving',
        type: TransactionType.savingsIn,
        amount: 200,
        dateTime: today.subtract(const Duration(days: 19)),
      ),
    ];
    await prefs.setStringList(
      TransactionStore.transactionsKey,
      records.map((r) => r.encode()).toList(),
    );
    TransactionStore.instance.resetCache();
    CurrencyStore.instance.resetCache();
    RecurringExpenseStore.instance.resetCache();
    ShoppingListStore.instance.resetCache();
    UsageStreakService.instance.resetCache();
    final tab = ValueNotifier<int>(4);
    addTearDown(tab.dispose);
    await tester.runAsync(() => SmartFactsLoader.load());
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ProfileScreen(tabIndex: tab),
        ),
      ),
    );
    await refreshHealth(tester);
    expect(
      tester.widget<WalletBackdrop>(find.byType(WalletBackdrop)).band,
      isIn([HealthBand.excellent, HealthBand.good]),
    );

    records.add(
      WaffrTransaction(
        id: 'withdrawal',
        type: TransactionType.savingsOut,
        amount: 200,
        dateTime: today,
      ),
    );
    await prefs.setStringList(
      TransactionStore.transactionsKey,
      records.map((r) => r.encode()).toList(),
    );
    TransactionStore.instance.resetCache();
    await tester.runAsync(() => SmartFactsLoader.load());
    await refreshHealth(tester);
    expect(
      tester.widget<WalletBackdrop>(find.byType(WalletBackdrop)).band,
      isIn([HealthBand.fair, HealthBand.low]),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
