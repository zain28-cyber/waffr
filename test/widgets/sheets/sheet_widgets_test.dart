// Smoke test for the shared "monthly income required" sheet.

import 'package:waffr/widgets/sheets/monthly_income_required_sheet.dart';

import '../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen(
    'monthly income required sheet',
    () => SheetLauncher(open: showMonthlyIncomeRequiredSheet),
    interact: openSheet,
  );
}
