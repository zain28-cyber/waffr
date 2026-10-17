// Smoke tests for the savings tab.

import 'package:waffr/screens/offline/savings/savings_screen.dart';

import '../../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen('SavingsScreen', () => const SavingsScreen());
}
