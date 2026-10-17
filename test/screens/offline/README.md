# test/screens/offline

Widget tests for `lib/screens/offline`.

Most tests are smoke tests built with `smokeTestScreen` / `smokeTestWidget`
from `test/helpers/widget_harness.dart`: each pumps the screen or widget
with the app theme, Arabic locale and RTL direction on a 390x844 phone
view, in light and dark (and with sample data where a screen reads the
stores), plus once with reduced motion, and fails on any exception or
layout overflow. Sheets and dialogs are opened through their public
`show…` function from a `SheetLauncher` page.

| File | Covers |
| --- | --- |
| `theme_select_screen_test.dart` | Smoke test for the first-launch theme picker. |

Subfolders:

- [applock/](applock/README.md)
- [home/](home/README.md)
- [login/](login/README.md)
- [notifications/](notifications/README.md)
- [obligations/](obligations/README.md)
- [placeholder/](placeholder/README.md)
- [profile/](profile/README.md)
- [report/](report/README.md)
- [savings/](savings/README.md)
- [settings/](settings/README.md)
- [smart/](smart/README.md)
- [user_info/](user_info/README.md)

Run them with:

```
flutter test test/screens/offline
```
