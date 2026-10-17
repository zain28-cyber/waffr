// Smoke test for the first-launch theme picker.

import 'package:waffr/screens/offline/theme_select_screen.dart';

import '../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen(
    'ThemeSelectScreen',
    () => ThemeSelectScreen(onThemeChanged: (_) {}, onContinue: () {}),
    withSampleData: false,
  );
}
