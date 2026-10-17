# test/screens/offline/report

Widget tests for `lib/screens/offline/report`.

Most tests are smoke tests built with `smokeTestScreen` / `smokeTestWidget`
from `test/helpers/widget_harness.dart`: each pumps the screen or widget
with the app theme, Arabic locale and RTL direction on a 390x844 phone
view, in light and dark (and with sample data where a screen reads the
stores), plus once with reduced motion, and fails on any exception or
layout overflow. Sheets and dialogs are opened through their public
`show…` function from a `SheetLauncher` page.

| File | Covers |
| --- | --- |
| `expense_history_pdf_test.dart` | Expense history PDF: the background-built document has day tables and totals. |
| `reportscreen_test.dart` | Smoke tests for the report tab and the transaction history screens. |

Run them with:

```
flutter test test/screens/offline/report
```
