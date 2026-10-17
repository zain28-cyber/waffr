// Smart analysis lifecycle: leaving the screen mid-generation cancels its
// pending timers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/core/insights/smart/smart_facts_loader.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/screens/offline/smart/smart_analysis_screen.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/widgets/smart/smart_glow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.instance;
    await prefs.clear();
    TransactionStore.instance.resetCache();
    RecurringExpenseStore.instance.resetCache();
    ShoppingListStore.instance.resetCache();
    CurrencyStore.instance.resetCache();
    UsageStreakService.instance.resetCache();
    await SmartFactsLoader.load();
  });

  Widget screen({bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: const SmartAnalysisScreen(scope: InsightScope.reports),
    ),
  );

  testWidgets('leaving during generation cancels the pending pause', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.runAsync(() async {
      await SmartFactsLoader.load();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<SmartSpark>(find.byType(SmartSpark)).spinning, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await SmartFactsLoader.load();
    });
    await tester.pump();
    // Pending timers or callbacks after disposal fail the binding invariant.
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rapid scope changes finish the latest report with reduced motion',
    (tester) async {
      await tester.pumpWidget(screen());
      await tester.runAsync(() async {
        await SmartFactsLoader.load();
      });
      await tester.pump();
      await tester.tap(find.text('التوفير').first);
      await tester.runAsync(() async {
        await SmartFactsLoader.load();
      });
      await tester.pump();
      await tester.tap(find.text('نظرة شاملة').first);
      await tester.runAsync(() async {
        await SmartFactsLoader.load();
      });
      await tester.pump();
      await tester.pumpWidget(screen(reduced: true));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SheetChoiceChips>(find.byType(SheetChoiceChips)).selected,
        'نظرة شاملة',
      );
      expect(
        tester.widget<SmartSpark>(find.byType(SmartSpark)).spinning,
        isFalse,
      );
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
