// Smoke tests for the shared dialogs: amount editor, date pickers and the
// edit / delete menu.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/dialogs/edit_amount_dialog.dart';
import 'package:waffr/widgets/dialogs/edit_delete_menu.dart';
import 'package:waffr/widgets/dialogs/waffr_date_picker.dart';

import '../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen(
    'EditAmountDialog',
    () => SheetLauncher(
      open: (context) => showDialog<void>(
        context: context,
        builder: (_) => const EditAmountDialog(
          title: 'title',
          initialAmount: 2500,
          accent: Colors.teal,
          allowClear: true,
        ),
      ),
    ),
    interact: openSheet,
    withSampleData: false,
  );
  smokeTestScreen(
    'date picker',
    () => SheetLauncher(
      open: (context) => showWaffrDatePicker(
        context: context,
        title: 'title',
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        initialDate: DateTime(2026, 5, 14),
      ),
    ),
    interact: openSheet,
    withSampleData: false,
  );
  smokeTestScreen(
    'date range picker',
    () => SheetLauncher(
      open: (context) => showWaffrDateRangePicker(
        context: context,
        title: 'title',
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      ),
    ),
    interact: openSheet,
    withSampleData: false,
  );
  smokeTestScreen(
    'edit / delete menu',
    () => SheetLauncher(
      open: (context) => showEditDeleteMenu(context, anchorContext: context),
    ),
    interact: openSheet,
    withSampleData: false,
  );
}
