// Smoke tests for every savings sheet, opened through its public show function.

import 'package:flutter/material.dart';
import 'package:waffr/data/models/shopping_item.dart';
import 'package:waffr/screens/offline/savings/sheets/completed_goals_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/create_goal_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/manage_goals_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/manual_save_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/periodic_goals_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/shopping_list_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/withdraw_savings_sheet.dart';

import '../../../../helpers/widget_harness.dart';

void main() {
  final sheets = <String, void Function(BuildContext)>{
    'create goal sheet': showCreateGoalSheet,
    'manage goals sheet': showManageGoalsSheet,
    'completed goals sheet': showCompletedGoalsSheet,
    'manual save sheet': showManualSaveSheet,
    'withdraw savings sheet': showWithdrawSavingsSheet,
    'periodic goals sheet': showPeriodicGoalsSheet,
    'shopping list sheet': showShoppingListSheet,
    'purchase shopping item sheet': (context) => showPurchaseShoppingItemSheet(
      context,
      ShoppingItem(id: 'item', name: 'item', createdAt: DateTime(2026, 1, 5)),
    ),
  };
  sheets.forEach((name, open) {
    smokeTestScreen(name, () => SheetLauncher(open: open), interact: openSheet);
  });

  smokeTestScreen(
    'ShoppingListPreviewCard',
    () => const Scaffold(body: ShoppingListPreviewCard()),
    screenType: ShoppingListPreviewCard,
  );
}
