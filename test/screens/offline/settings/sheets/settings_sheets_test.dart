// Smoke tests for the currencies and monthly income sheets.

import 'package:waffr/screens/offline/settings/sheets/currencies_sheet.dart';
import 'package:waffr/screens/offline/settings/sheets/monthly_income_sheet.dart';

import '../../../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen(
    'currencies sheet',
    () => SheetLauncher(open: showCurrenciesSheet),
    interact: openSheet,
  );
  smokeTestScreen(
    'add currency sheet',
    () => SheetLauncher(open: showAddCurrencySheet),
    interact: openSheet,
  );
  smokeTestScreen(
    'monthly income sheet',
    () => SheetLauncher(
      open: (context) => showMonthlyIncomeSheet(
        context,
        title: 'title',
        initialAmount: 250000,
        allowClear: true,
      ),
    ),
    interact: openSheet,
  );
}
