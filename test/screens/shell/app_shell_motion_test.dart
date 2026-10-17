// Shell motion: a retained tab stops its tickers when another tab is shown.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/screens/shell/app_shell.dart';
import 'package:waffr/screens/offline/profile/wallet_backdrop.dart';

void main() {
  testWidgets('retained profile stops motion when returning to another tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.instance;
    await prefs.clear();
    TransactionStore.instance.resetCache();
    CurrencyStore.instance.resetCache();
    NotificationService.instance.resetCache();
    final theme = ValueNotifier(ThemeMode.light);
    addTearDown(theme.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ar')],
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AppShell(
            themeNotifier: theme,
            onThemeChanged: () {},
            appFlowController: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_rounded).last);
    await tester.pumpAndSettle();
    expect(find.byType(WalletBackdrop), findsOneWidget);
    final profileContext = tester.element(find.byType(WalletBackdrop));
    expect(TickerMode.valuesOf(profileContext).enabled, isTrue);
    await tester.tap(find.byIcon(Icons.home_rounded).last);
    await tester.pumpAndSettle();
    expect(TickerMode.valuesOf(profileContext).enabled, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
    // The app-wide home-widget service outlives the shell. Flush its
    // store-write debounce; native plugins are not available in this test.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
