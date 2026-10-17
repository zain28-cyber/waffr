// Smoke tests for the obligations sheet and the due obligations sheet.

import 'package:waffr/screens/offline/obligations/obligations_sheet.dart';

import '../../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen(
    'obligations sheet',
    () => SheetLauncher(open: showObligationsSheet),
    interact: openSheet,
  );
  smokeTestScreen(
    'due obligations sheet',
    () => SheetLauncher(open: showDueObligationsSheet),
    interact: openSheet,
  );
}
