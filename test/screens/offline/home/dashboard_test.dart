// Smoke tests for the home tab (HomeScreen) and its add-expense / add-income
// sheets: light and dark, empty and populated, RTL on a phone-sized view.

import 'package:waffr/screens/offline/home/dashboard.dart';
import 'package:waffr/screens/offline/home/sheets/add_expense_sheet.dart';
import 'package:waffr/screens/offline/home/sheets/add_income_sheet.dart';

import '../../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen('HomeScreen', () => const HomeScreen());

  smokeTestScreen(
    'add expense sheet',
    () => SheetLauncher(open: showAddExpenseSheet),
    interact: openSheet,
  );

  smokeTestScreen(
    'add income sheet',
    () => SheetLauncher(open: showAddIncomeSheet),
    interact: openSheet,
  );
}
