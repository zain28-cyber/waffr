# Settings sheets

Glass bottom sheets opened from `SettingsScreen`. Both use `showGlassSheet`
and the shared sheet pieces from `widgets/containers/glass_sheet.dart`.

| File | Entry point | What it does |
| --- | --- | --- |
| `currencies_sheet.dart` | `showCurrenciesSheet`, `showAddCurrencySheet` | List enabled currencies, set the active one, hide extra ones (their ledger is kept), and add one from a stacked picker. |
| `monthly_income_sheet.dart` | `showMonthlyIncomeSheet` | Amount + currency form for the monthly (or weekly) income. |

How they connect:

- The currencies sheets read and write `CurrencyStore` directly
  (`setActive`, `removeCurrency`, `addCurrency`) and rebuild from it. The
  default currency cannot be hidden.
- `showMonthlyIncomeSheet` does not save anything. It pops an
  `EditAmountResult` (amount and currency) or, when `allowClear` is set and
  the user taps remove, an `AmountDialogCleared`; both types come from
  `widgets/dialogs/edit_amount_dialog.dart`. `SettingsScreen._editIncome`
  stores the result in `TransactionStore`.
