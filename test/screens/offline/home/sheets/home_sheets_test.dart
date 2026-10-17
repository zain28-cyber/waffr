// Smoke tests for the expense presets dialog and the category grid used by
// the add-expense sheet.

import 'package:flutter/material.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/screens/offline/home/sheets/add_expense_sheet.dart';
import 'package:waffr/screens/offline/home/sheets/expense_presets_dialog.dart';

import '../../../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen(
    'expense presets dialog',
    () => SheetLauncher(
      open: (context) => showExpensePresetsDialog(context, marked: false),
    ),
    interact: openSheet,
  );

  smokeTestScreen(
    'ExpenseCategoryGrid',
    () => Scaffold(
      body: SingleChildScrollView(
        child: ExpenseCategoryGrid(
          selected: expenseCategories.first.label,
          onSelected: (_) {},
        ),
      ),
    ),
    screenType: ExpenseCategoryGrid,
  );
}
