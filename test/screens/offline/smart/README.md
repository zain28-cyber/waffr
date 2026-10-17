# test/screens/offline/smart

Widget tests for `lib/screens/offline/smart`.

Most tests are smoke tests built with `smokeTestScreen` / `smokeTestWidget`
from `test/helpers/widget_harness.dart`: each pumps the screen or widget
with the app theme, Arabic locale and RTL direction on a 390x844 phone
view, in light and dark (and with sample data where a screen reads the
stores), plus once with reduced motion, and fails on any exception or
layout overflow. Sheets and dialogs are opened through their public
`show…` function from a `SheetLauncher` page.

| File | Covers |
| --- | --- |
| `smart_analysis_screen_test.dart` | Smoke tests for the smart analysis screen in every insight scope. |
| `smart_generation_lifecycle_test.dart` | Smart analysis lifecycle: leaving the screen mid-generation cancels its pending timers. |

Run them with:

```
flutter test test/screens/offline/smart
```
