// Smoke tests for the report tab and the transaction history screens.

import 'package:waffr/screens/offline/report/reportscreen.dart';

import '../../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen('ReportScreen', () => const ReportScreen());
  smokeTestScreen(
    'expense history',
    () => const TransactionHistoryScreen.expenses(),
  );
  smokeTestScreen(
    'income history',
    () => const TransactionHistoryScreen.incomes(),
  );
}
