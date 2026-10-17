# test/widgets/dialogs

Widget tests for `lib/widgets/dialogs`.

Most tests are smoke tests built with `smokeTestScreen` / `smokeTestWidget`
from `test/helpers/widget_harness.dart`: each pumps the screen or widget
with the app theme, Arabic locale and RTL direction on a 390x844 phone
view, in light and dark (and with sample data where a screen reads the
stores), plus once with reduced motion, and fails on any exception or
layout overflow. Sheets and dialogs are opened through their public
`show…` function from a `SheetLauncher` page.

| File | Covers |
| --- | --- |
| `dialog_widgets_test.dart` | Smoke tests for the shared dialogs: amount editor, date pickers and the edit / delete menu. |

Run them with:

```
flutter test test/widgets/dialogs
```
