// Smoke tests for the profile details step and the country picker.

import 'package:waffr/screens/offline/user_info/country_picker_sheet.dart';
import 'package:waffr/screens/offline/user_info/user_info_screen.dart';

import '../../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen(
    'UserInfoScreen',
    () => UserInfoScreen(onContinue: (_) {}),
    withSampleData: false,
  );
  smokeTestScreen(
    'country picker sheet',
    () => SheetLauncher(open: (context) => showCountryPickerSheet(context)),
    interact: openSheet,
    withSampleData: false,
  );
}
