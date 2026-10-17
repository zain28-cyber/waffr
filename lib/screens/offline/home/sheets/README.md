# Home sheets

Bottom sheets for adding money in and out, opened from the home tab, the
shell's quick actions and home-screen widget links, and smart analysis
actions. All use the glass sheet kit from `widgets/containers/glass_sheet.dart`.

| File | Main entry point | What it is |
| --- | --- | --- |
| `add_expense_sheet.dart` | `showAddExpenseSheet` | One-off or recurring expense form: amount with currency and multiplier, frequency and deduct mode for recurring, category grid, note with smart category suggestion, preset star. |
| `expense_category_grid.dart` | `ExpenseCategoryGrid` | Part of `add_expense_sheet.dart`. Category tiles (long-press to edit / remove), the custom category dialog, and `_SmartCategoryHint`. |
| `expense_presets_dialog.dart` | `showExpensePresetsDialog` | Saved-expense (preset) picker opened from the star; returns an `ExpensePresetChoice` (mark, unmark, or a selected preset). |
| `add_income_sheet.dart` | `showAddIncomeSheet` | Income form: amount, frequency (monthly or one-off; weekly is hidden), what to do with the leftover balance, optional source. |

How it connects:

- A one-off expense goes to `TransactionStore.addExpense`, which refuses it
  when the balance in that currency is too low. A recurring expense becomes
  an obligation through `RecurringExpenseStore.addExpense`; its default
  deduct mode is "automatic" when a monthly income is set, else "confirm".
- Categories come from `CategoryStore`; suggestions from
  `CategorySuggester` when `SmartSettings.categorize` is on. Presets live in
  `ExpensePresetStore` and are saved only after the expense itself is saved.
- Saving income calls `TransactionStore.addIncome`, then
  `RecurringExpenseStore.releaseIncomeReminders`; if obligations still wait
  for confirmation it offers `showDueObligationsSheet`.
- The deduct-mode labels and info text (`kDeduct*`) come from
  `obligations/obligations_sheet.dart`.

Conventions: the expense sheet rebuilds only its body on each keystroke
(`ListenableBuilder` over the amount and interval controllers), while the
category grid is built once per state change.

Tests: `test/screens/offline/home/sheets/home_sheets_test.dart`.
