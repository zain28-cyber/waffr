// Widget smoke-test harness: pumps a screen inside the app's real theme,
// Arabic locale and RTL direction on a phone-sized view, and checks that it
// renders without exceptions or layout overflows in light and dark mode.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/l10n/waffr_material_localizations.dart';
import 'package:waffr/core/theme/app_theme.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import 'store_harness.dart';

/// Logical size of a typical phone (iPhone 13 / Pixel 7 class).
const Size kPhoneSize = Size(390, 844);

/// The app's MaterialApp setup (theme, Arabic locale, RTL) around [home].
/// [reduceMotion] turns on the accessibility "remove animations" setting.
Widget wrapInApp(
  Widget home, {
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      WaffrMaterialLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Directionality(textDirection: TextDirection.rtl, child: child!),
    ),
    home: home,
  );
}

/// Sizes the test view like a phone; restored after the test.
void usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = kPhoneSize * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Answers the platform channels the app touches with harmless defaults, so
/// plugins without a test implementation do not throw.
void mockPlatformPlugins() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in const [
    'dev.fluttercommunity.plus/connectivity',
    'dexterous.com/flutter/local_notifications',
    'home_widget',
    'plugins.flutter.io/url_launcher',
    'dev.fluttercommunity.plus/share',
    'plugins.flutter.io/path_provider',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      if (call.method == 'check') return 'none';
      return null;
    });
  }
}

/// Pumps frames for [duration] so entrance animations, staggered reveals and
/// async store loads finish (pumpAndSettle would wait forever on looping
/// decorations).
Future<void> pumpFor(
  WidgetTester tester, [
  Duration duration = const Duration(seconds: 3),
]) async {
  const step = Duration(milliseconds: 100);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += step) {
    await tester.pump(step);
  }
}

/// Fails if a build, layout or paint error (e.g. a RenderFlex overflow) was
/// reported, and checks the screen is laid out right to left.
void expectCleanRender(WidgetTester tester, Type screenType) {
  expect(tester.takeException(), isNull);
  final screen = find.byType(screenType);
  expect(screen, findsWidgets);
  expect(Directionality.of(tester.element(screen.first)), TextDirection.rtl);
}

/// Unmounts the app and lets debounced writes and timers run out, so the
/// test ends without pending timers.
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await pumpFor(tester, const Duration(seconds: 2));
  expect(tester.takeException(), isNull);
}

/// Fills the ledger with a few rows so screens draw their populated state:
/// a monthly income, expenses in two categories, a goal and a shopping item.
Future<void> seedSampleData() async {
  final store = TransactionStore.instance;
  await store.addIncome(amount: 1500000, frequency: RecurringFrequency.monthly);
  await store.addExpense(
    amount: 125000,
    category: expenseCategories[0].label,
    paymentMethod: paymentMethods.first,
  );
  await store.addExpense(
    amount: 48000,
    category: expenseCategories[1].label,
    paymentMethod: paymentMethods.first,
    note: 'note',
  );
  await store.createGoal(
    name: 'goal',
    targetAmount: 900000,
    duration: GoalDurationPreset.month,
    allocatePercent: 10,
  );
  await ShoppingListStore.instance.addItem('item');
}

/// Registers one smoke test per theme brightness (and per data state when
/// [withSampleData] is set), plus one with reduced motion, that pumps
/// [build] on a phone-sized RTL view and checks it renders cleanly.
void smokeTestScreen(
  String name,
  Widget Function() build, {
  Type? screenType,
  bool withSampleData = true,
  Duration settle = const Duration(seconds: 3),
  Future<void> Function(WidgetTester tester)? interact,
}) {
  final variants = <({Brightness brightness, bool seeded, bool reduced})>[
    for (final brightness in Brightness.values)
      for (final seeded in withSampleData ? const [false, true] : const [false])
        (brightness: brightness, seeded: seeded, reduced: false),
    (brightness: Brightness.light, seeded: withSampleData, reduced: true),
  ];
  for (final variant in variants) {
    final label =
        '$name renders in ${variant.brightness.name} mode'
        '${variant.seeded ? ' with data' : ''}'
        '${variant.reduced ? ' with reduced motion' : ''}';
    testWidgets(label, (tester) async {
      usePhoneView(tester);
      mockPlatformPlugins();
      await tester.runAsync(() async {
        await setUpStores();
        if (variant.seeded) await seedSampleData();
      });
      final screen = build();
      await tester.pumpWidget(
        wrapInApp(
          screen,
          brightness: variant.brightness,
          reduceMotion: variant.reduced,
        ),
      );
      await pumpFor(tester, settle);
      expectCleanRender(tester, screenType ?? screen.runtimeType);
      if (interact != null) {
        await interact(tester);
        await pumpFor(tester, settle);
        expect(tester.takeException(), isNull);
      }
      await unmountApp(tester);
    });
  }
}

/// A screen with one button that runs [open] (e.g. `showAddExpenseSheet`), so
/// sheets and dialogs can be smoke tested through their public entry point.
class SheetLauncher extends StatelessWidget {
  /// Opens the sheet or dialog under test.
  final void Function(BuildContext context) open;

  /// Creates a [SheetLauncher].
  const SheetLauncher({super.key, required this.open});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

/// Taps the [SheetLauncher] button.
Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
}

/// Smoke tests one shared widget: placed on a plain page (or, with
/// [wrap] false, as the page itself), in light, dark and reduced motion.
/// [find] names the type to look for when [type] sits inside a wrapper.
void smokeTestWidget(
  Type type,
  Widget Function() build, {
  String? name,
  bool wrap = true,
  Type? find,
  Future<void> Function(WidgetTester tester)? interact,
}) {
  smokeTestScreen(
    name ?? type.toString(),
    () => wrap
        ? Scaffold(
            body: Center(
              child: Padding(padding: const EdgeInsets.all(20), child: build()),
            ),
          )
        : build(),
    screenType: find ?? type,
    withSampleData: false,
    interact: interact,
  );
}
