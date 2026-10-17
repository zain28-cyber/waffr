// Smoke test for the app lock screen.

import 'package:waffr/screens/offline/applock/applockscreen.dart';

import '../../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen(
    'LockScreen',
    () => LockScreen(onAuthenticated: () {}),
    withSampleData: false,
  );
}
