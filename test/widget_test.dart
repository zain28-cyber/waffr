// App-level smoke tests for lib/main.dart: WafarApp boots into the right
// first gate (sign-in on a fresh install, the shell for a returning guest)
// in RTL on a phone-sized view without exceptions.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/services/backup_service.dart';
import 'package:waffr/main.dart';
import 'package:waffr/screens/offline/login/login_screen.dart';
import 'package:waffr/screens/shell/app_shell.dart';

import 'helpers/store_harness.dart';
import 'helpers/widget_harness.dart';

void main() {
  testWidgets('a fresh install opens on the sign-in screen', (tester) async {
    usePhoneView(tester);
    mockPlatformPlugins();
    await tester.runAsync(setUpStores);

    await tester.pumpWidget(const WafarApp());
    await pumpFor(tester);

    expectCleanRender(tester, LoginScreen);
    await unmountApp(tester);
  });

  testWidgets('a returning guest goes straight to the shell', (tester) async {
    usePhoneView(tester);
    mockPlatformPlugins();
    await tester.runAsync(() async {
      final prefs = await setUpStores();
      await prefs.setBool('first_launch', false);
      await prefs.setBool(BackupService.authChoiceKey, true);
      await prefs.setBool('dark_mode', true);
      resetStoreCaches();
    });

    await tester.pumpWidget(const WafarApp());
    await pumpFor(tester);

    expectCleanRender(tester, AppShell);
    await unmountApp(tester);
  });
}
