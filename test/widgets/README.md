# test/widgets

Widget tests for the shared widgets in `lib/widgets`, one folder per
`lib/widgets` folder.

Most tests are smoke tests built with `smokeTestScreen` / `smokeTestWidget`
from `test/helpers/widget_harness.dart`: each pumps the screen or widget
with the app theme, Arabic locale and RTL direction on a 390x844 phone
view, in light and dark (and with sample data where a screen reads the
stores), plus once with reduced motion, and fails on any exception or
layout overflow. Sheets and dialogs are opened through their public
`show…` function from a `SheetLauncher` page.

Subfolders:

- [brand/](brand/README.md)
- [button/](button/README.md)
- [containers/](containers/README.md)
- [dialogs/](dialogs/README.md)
- [motion/](motion/README.md)
- [sheets/](sheets/README.md)
- [smart/](smart/README.md)

Run them with:

```
flutter test test/widgets
```
