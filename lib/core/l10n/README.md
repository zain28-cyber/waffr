# lib/core/l10n

The app ships one locale, Arabic (`ar`), with Western digits (0-9)
everywhere. Flutter's stock Arabic Material strings use Arabic-Indic digits
and Egyptian month names in the date pickers, so this folder overrides them.

| File | Contents |
| --- | --- |
| `waffr_material_localizations.dart` | `WaffrMaterialLocalizations` (extends `MaterialLocalizationAr`) and its `delegate`; also the top-level `westernDigits(text)` helper. |

What it changes:

- Calendar days, years and headers are formatted with 0-9.
- intl month names are mapped to the Levantine names used elsewhere in the
  app (`CalendarPeriod.monthNames`), e.g. "كانون الثاني" for January.
- Typed dates use the same DD/MM/YYYY shape as `core/utils/date_input.dart`
  (`dateHelpText` is `dateInputHint`).

Conventions:

- `main.dart` registers `WaffrMaterialLocalizations.delegate` **before**
  `GlobalMaterialLocalizations.delegate`, so it wins for `ar`.
- The delegate loads synchronously (like the global one), so the first
  frame is not held back.
- `widgets/dialogs/waffr_date_picker.dart` relies on it for its calendar.
