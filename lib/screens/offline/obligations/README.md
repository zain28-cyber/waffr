# Obligations

Sheets for recurring expenses ("obligations"). One library:
`obligations_sheet.dart` holds the imports and `part` directives; the other
three files start with `part of 'obligations_sheet.dart'`. Import only
`obligations_sheet.dart`; it also gives access to the shared labels.

| File | What it holds |
| --- | --- |
| `obligations_sheet.dart` | `showObligationsSheet`, `showDueObligationsSheet`, `ObligationsSheet` (monthly total, next charge, awaiting banner, one tile per obligation). |
| `obligation_details_sheet.dart` | `_ObligationDetailsSheet`: edit amount, deduct mode, active / paused, review, delete. |
| `due_obligations_sheet.dart` | `DueObligationsSheet`: per obligation, deduct one, deduct all missed payments, or postpone (1 day, 3 days, a week, next income). |
| `obligation_labels.dart` | Public helpers `obligationTitle`, `obligationDate`, `obligationStatus`, `obligationNeedsAttention`, `paymentsLabel`, `obligationsCountLabel`, the `kDeduct*` labels; private `_ObligationColors` and `_text`. |

How it connects:

- All data and changes go through `RecurringExpenseStore` (`itemsFor`,
  `awaitingConfirmation`, `nextUpcoming`, `monthlyTotal`, `confirmDue`,
  `postpone`, `updateAmount`, `setEnabled`, `setRequiresConfirmation`,
  `deleteExpense`). The list follows the active currency (`CurrencyStore`);
  the due sheet covers every currency.
- Opened from the home expenses card, settings, notifications, the shell
  (widget link), smart analysis actions, and the add-income sheet (after
  income, when charges are waiting).
- The home dashboard and the add-expense sheet reuse the labels.

Conventions: times come from `deviceNow()` (core/sync/sync_clock). The due
sheet snapshots its items on open so they do not vanish while the user
chooses. A charge "needs attention" when it is due but not deducted, either
waiting for confirmation or short of balance.

Tests: `test/screens/offline/obligations/obligations_sheet_test.dart`.
