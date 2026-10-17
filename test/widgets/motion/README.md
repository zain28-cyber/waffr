# test/widgets/motion

Widget tests for `lib/widgets/motion`.

Most tests are smoke tests built with `smokeTestScreen` / `smokeTestWidget`
from `test/helpers/widget_harness.dart`: each pumps the screen or widget
with the app theme, Arabic locale and RTL direction on a 390x844 phone
view, in light and dark (and with sample data where a screen reads the
stores), plus once with reduced motion, and fails on any exception or
layout overflow. Sheets and dialogs are opened through their public
`show…` function from a `SheetLauncher` page.

| File | Covers |
| --- | --- |
| `active_listenable_builder_test.dart` | ActiveListenableBuilder: hidden tabs skip rebuilds and catch up when shown. |
| `motion_lifecycle_test.dart` | Motion widget lifecycles: reveals, rolling money and text, glows and the streak number cancel timers and honor reduced motion and text scaling. |
| `motion_test.dart` | Motion basics: reduced-motion page transitions and reveals that keep their child alive after the entrance. |
| `motion_widgets_test.dart` | Smoke tests for the shared motion widgets at rest and mid-animation. |

Run them with:

```
flutter test test/widgets/motion
```
