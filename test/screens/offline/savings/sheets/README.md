# test/screens/offline/savings/sheets

Widget tests for `lib/screens/offline/savings/sheets`.

Most tests are smoke tests built with `smokeTestScreen` / `smokeTestWidget`
from `test/helpers/widget_harness.dart`: each pumps the screen or widget
with the app theme, Arabic locale and RTL direction on a 390x844 phone
view, in light and dark (and with sample data where a screen reads the
stores), plus once with reduced motion, and fails on any exception or
layout overflow. Sheets and dialogs are opened through their public
`show…` function from a `SheetLauncher` page.

| File | Covers |
| --- | --- |
| `savings_sheets_test.dart` | Smoke tests for every savings sheet, opened through its public show function. |

Run them with:

```
flutter test test/screens/offline/savings/sheets
```
