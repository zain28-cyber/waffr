# test/widgets/brand

Widget tests for `lib/widgets/brand`.

Most tests are smoke tests built with `smokeTestScreen` / `smokeTestWidget`
from `test/helpers/widget_harness.dart`: each pumps the screen or widget
with the app theme, Arabic locale and RTL direction on a 390x844 phone
view, in light and dark (and with sample data where a screen reads the
stores), plus once with reduced motion, and fails on any exception or
layout overflow. Sheets and dialogs are opened through their public
`show…` function from a `SheetLauncher` page.

| File | Covers |
| --- | --- |
| `brand_widgets_test.dart` | Smoke tests for the brand widgets: avatar, logo, splash, page headers and the rolling streak number. |
| `streak_celebration_test.dart` | Streak celebration overlay: finishes once, can be skipped, and is skipped entirely under reduced motion. |

Run them with:

```
flutter test test/widgets/brand
```
