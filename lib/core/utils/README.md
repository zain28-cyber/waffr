# lib/core/utils

Formatting and feedback helpers shared by screens, widgets and stores.

| File | Contents |
| --- | --- |
| `money.dart` | `formatMoney(value)` ("1,500", whole amounts, 0-9 digits), `formatDate` (DD/MM/YYYY), `formatTime` (HH:mm), `currencyLabel` (active symbol from `CurrencyStore`), `currencyLabelFor(code)`, `sypCurrencyLabel`. |
| `date_input.dart` | Typed dates: `DateInputFormatter` (inserts `/` while digits are typed), `parseDateInput`, `isDateInputComplete`, `dateInputError`, `formatDateInput`, `dateInputHint`. |
| `calendar_days.dart` | `calendarDaysBetween(from, to)` and `addCalendarDays(date, n)`: day arithmetic by date, so a 23- or 25-hour daylight-saving day still counts as one day. Use them instead of `difference(...).inDays` / `add(Duration(days: n))` for calendar days. |
| `app_feedback.dart` | One visual language for messages: `showAppSnackBar(kind:)` with `AppFeedbackKind`, `showInsufficientBalanceMessage`, `showAppDialog`, `AppDialogFrame` / `AppDialogAction` / `AppDialogActionButton`, `showAppConfirmDialog`, `showAppInfoDialog`, `AppInlineMessage`. |

How it connects:

- `money.dart` reads `CurrencyStore.instance` (lib/data), so it is one of
  the places where core depends on data.
- `date_input.dart` is used by `widgets/dialogs/waffr_date_picker.dart`
  (its typed fields) and `core/l10n` (picker help text).
- `app_feedback.dart` is imported by most screens and by the sheet widgets
  (`SheetInfoButton` opens `showAppInfoDialog`).

Conventions:

- All user-facing numbers and dates use Western digits (0-9), never
  locale-dependent `DateFormat` data.
- Do not build `SnackBar`s or `AlertDialog`s by hand: confirmations use
  `showAppConfirmDialog` (`destructive: true` for deletes), short help uses
  `showAppInfoDialog`, and form errors next to fields use `AppInlineMessage`.
