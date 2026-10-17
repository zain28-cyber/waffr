# lib/widgets/dialogs

Shared dialogs and popups. Dialogs open through `showAppDialog` (from
`core/utils/app_feedback.dart`) so every dialog fades and slides the same
way; the edit/delete popup is a themed `showMenu`.

| File | Contents |
| --- | --- |
| `edit_amount_dialog.dart` | `EditAmountDialog(title:, initialAmount:, accent:, allowClear:, currencyCode:)`: one amount plus currency, same validation as monthly income. Pops `EditAmountResult(amount, currencyCode)` or, with `allowClear`, `AmountDialogCleared`. |
| `edit_delete_menu.dart` | `showEditDeleteMenu(context, anchorContext:, allowEdit:)` -> `EditDeleteAction?`: the small long-press edit / delete popup anchored to a tile. |
| `waffr_date_picker.dart` | `showWaffrDatePicker(...)` -> `DateTime?` and `showWaffrDateRangePicker(...)` -> `DateTimeRange?`: a typed DD/MM/YYYY field (one per date) above a calendar, kept in sync both ways. |

Who uses them:

- `EditAmountDialog` / `EditAmountResult`: obligation details, the
  obligations sheet, Settings and the monthly income sheet (which pops the
  same `EditAmountResult` type).
- `showEditDeleteMenu`: expense categories on the add-expense sheet and
  shopping-list items, so both long-press menus look the same.
- The date pickers: transaction history (range filter, a part of
  `reportscreen.dart`) and the user-info form (birth date).

Conventions:

- Dialogs use `AppDialogFrame` for their shell and the sheet field pieces
  re-exported by `glass_sheet.dart` (`SheetCurrencySelector`,
  `ThousandsInputFormatter`, field fill color).
- Pickers show 0-9 digits and Levantine month names through
  `WaffrMaterialLocalizations`; typing uses `core/utils/date_input.dart`,
  so only the number pad is needed and impossible dates are rejected.
- Cancel always returns null; callers check the result type before acting.
