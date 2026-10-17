# Savings sheets

Bottom sheets opened from the savings tab. Each file exposes one public
`show...Sheet(context)` function that wraps a private widget in
`showGlassSheet` (from `widgets/containers/glass_sheet.dart`); the widgets
themselves stay private.

| File | Entry point | What it does |
| --- | --- | --- |
| `create_goal_sheet.dart` | `showCreateGoalSheet` | New goal: name, target, and percent / fixed / custom funding with a periods preview. |
| `manage_goals_sheet.dart` | `showManageGoalsSheet` | Reorder goals by drag (priority), delete, or add one (opens the create sheet on top). |
| `completed_goals_sheet.dart` | `showCompletedGoalsSheet` | Read-only list of completed goals. |
| `periodic_goals_sheet.dart` | `showPeriodicGoalsSheet` | Percent-of-monthly-income plan: picker, then preview; or the active plan's details with delete. |
| `manual_save_sheet.dart` | `showManualSaveSheet` | Move an amount from the balance into savings. |
| `withdraw_savings_sheet.dart` | `showWithdrawSavingsSheet` | Move an amount from savings back to the balance. |
| `shopping_list_sheet.dart` | `ShoppingListPreviewCard`, `showShoppingListSheet`, `showPurchaseShoppingItemSheet`, `itemsCountLabel` | Shopping list card, full list sheet, and the purchase-as-expense sheet. |

How they connect:

- Goal, plan and savings sheets read and write `TransactionStore`
  (`createGoal`, `reorderActiveGoals`, `deleteGoal`, `applyPeriodicPlan`,
  `saveManually`, `withdrawFromSavings`). Amount sheets use
  `SheetAmountField` with a per-sheet currency, defaulting to
  `CurrencyStore.instance.activeCode`.
- Percent and fixed funding need a configured income; without it the
  create and periodic sheets show `showMonthlyIncomeRequiredSheet`
  (`widgets/sheets`).
- The shopping list uses `ShoppingListStore`; recording a purchase calls
  `completePurchase`, which posts a normal expense. Its category grid
  (`ExpenseCategoryGrid`) comes from `home/sheets/add_expense_sheet.dart`.
- Successful saves fire `AppHaptics.success()` and pop the sheet; confirms
  use `showAppConfirmDialog` from `core/utils/app_feedback.dart`.
