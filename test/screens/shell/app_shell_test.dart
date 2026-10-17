// Smoke test for the app shell with its bottom navigation and tabs.

import 'package:flutter/material.dart';
import 'package:waffr/screens/shell/app_shell.dart';

import '../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen(
    'AppShell',
    () => AppShell(
      themeNotifier: ValueNotifier(ThemeMode.light),
      onThemeChanged: () {},
      appFlowController: null,
    ),
  );
}
