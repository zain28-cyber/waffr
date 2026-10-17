// Pinned period selector: stays pinned and tappable while each tab scrolls.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/screens/offline/report/reportscreen.dart';
import 'package:waffr/screens/offline/savings/savings_screen.dart';
import 'package:waffr/widgets/containers/floating_glass.dart';
import 'package:waffr/widgets/containers/pinned_period_scroll_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await (await AppPrefs.instance).clear();
    TransactionStore.instance.resetCache();
    CurrencyStore.instance.resetCache();
    CategoryStore.instance.resetCache();
    ShoppingListStore.instance.resetCache();
    await Future.wait([
      TransactionStore.instance.ensureLoaded(),
      CurrencyStore.instance.ensureLoaded(),
      CategoryStore.instance.ensureLoaded(),
      ShoppingListStore.instance.ensureLoaded(),
    ]);
  });

  Widget app(Widget screen, {bool dark = false, double scale = 1}) =>
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 640),
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: screen,
          ),
        ),
      );

  for (final entry in {
    'reports': const ReportScreen(),
    'savings': const SavingsScreen(),
  }.entries) {
    testWidgets('${entry.key} keeps the selector pinned and interactive', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(entry.value));
      await tester.pumpAndSettle();
      final selector = find.byType(FloatingPeriodSelector);
      final original = tester.getRect(selector);
      final page = tester.widget<PageView>(find.byType(PageView));
      await tester.tap(find.byTooltip('الفترة السابقة').first);
      await tester.pumpAndSettle();
      expect(page.controller!.page, 1);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scrollable.position.pixels, greaterThan(0));
      final verticalOffset = scrollable.position.pixels;
      expect(tester.getRect(selector), original);
      expect(
        find.descendant(of: selector, matching: find.byType(FloatingGlass)),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: selector, matching: find.text('أسبوع')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FloatingPeriodSelector>(selector).selected, 'أسبوع');
      expect(page.controller!.page, 0);
      // Changing the period must not jump the vertical scroll position.
      expect(scrollable.position.pixels, verticalOffset);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'scaled RTL dark selector exposes every period without clipping',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 'شهر';
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) => PinnedPeriodScrollView(
              options: const [
                'اليوم',
                'أسبوع',
                'شهر',
                '3 أشهر',
                '6 أشهر',
                'سنة',
              ],
              selected: selected,
              onSelected: (value) => setState(() => selected = value),
              child: const SizedBox(height: 1000),
            ),
          ),
          dark: true,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      final selector = find.byType(FloatingPeriodSelector);
      final position = tester.getRect(selector);
      expect(position.contains(tester.getCenter(find.text('شهر'))), isTrue);
      final horizontal = find.descendant(
        of: selector,
        matching: find.byType(SingleChildScrollView),
      );
      await tester.dragUntilVisible(
        find.text('سنة'),
        find.descendant(of: horizontal, matching: find.byType(Scrollable)),
        const Offset(180, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('سنة'));
      await tester.pumpAndSettle();
      expect(selected, 'سنة');
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text('سنة')),
        matchesSemantics(
          label: 'سنة',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      semantics.dispose();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(selector), position);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
