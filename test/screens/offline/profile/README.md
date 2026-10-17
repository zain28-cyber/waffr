# test/screens/offline/profile

Widget tests for `lib/screens/offline/profile`.

Most tests are smoke tests built with `smokeTestScreen` / `smokeTestWidget`
from `test/helpers/widget_harness.dart`: each pumps the screen or widget
with the app theme, Arabic locale and RTL direction on a 390x844 phone
view, in light and dark (and with sample data where a screen reads the
stores), plus once with reduced motion, and fails on any exception or
layout overflow. Sheets and dialogs are opened through their public
`show…` function from a `SheetLauncher` page.

| File | Covers |
| --- | --- |
| `profile_screen_test.dart` | Smoke tests for the profile tab and its streak card. |
| `profile_wallet_health_test.dart` | Profile wallet health: the backdrop band follows real saving and a later withdrawal. |
| `wallet_backdrop_motion_test.dart` | Wallet backdrop motion: animation runs only while the profile tab is active and motion is allowed. |

Run them with:

```
flutter test test/screens/offline/profile
```
