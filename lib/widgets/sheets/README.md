# lib/widgets/sheets

Complete bottom sheets reused by more than one feature. Sheets that belong
to one feature live next to their screen (`screens/**/sheets/`).

| File | Contents |
| --- | --- |
| `monthly_income_required_sheet.dart` | `showMonthlyIncomeRequiredSheet(context)`: explains that a periodic savings plan needs a monthly income set in Settings, with one "OK" button that dismisses it. |

Who uses it: `screens/offline/savings/sheets/create_goal_sheet.dart` and
`periodic_goals_sheet.dart`, when a plan based on income is chosen but no
income is known (`TransactionStore.hasConfiguredMonthlyIncome` is false, or
the reference income is 0).

How sheets here are built:

- Open with `showGlassSheet` and lay out with `GlassSheetBody` +
  `GlassSheetHeader` from `widgets/containers/glass_sheet.dart`; finish with
  `SheetSaveButton`. Do not copy the padding, handle or header row.
- Colors from `AppPalette.of(context)`; text is Arabic and centered.
- A sheet only explains or collects input; it does not write to the stores
  itself unless the caller passes that responsibility in.
