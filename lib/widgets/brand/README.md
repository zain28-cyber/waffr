# lib/widgets/brand

Waffr's identity pieces: the logo, the top bars, the avatar and the streak
celebration.

| File | Contents |
| --- | --- |
| `waffr_logo.dart` | `WaffrLogo` (the official wallet mark asset) and `WaffrSplash` (shown by `main.dart` while theme and gate flags resolve; matches the app background). |
| `waffr_page_header.dart` | `WaffrPageHeader` (fixed-height shell / settings top bar with optional scroll shadow) and `WaffrBackHeader` (back arrow + centered title for every pushed screen). |
| `profile_avatar.dart` | `ProfileAvatar`: person icon on an accent circle, crossed out for guests (`signedIn: false`). There are no profile photos. |
| `streak_celebration.dart` | `StreakCelebrationOverlay` (blur, logo rise, rolling day count, fade; tap skips; calls `onFinished`) and `RollingNumber` (odometer digits driven by a 0..1 progress). |

Who uses them:

- `WaffrLogo` / `WaffrSplash`: `main.dart`, login, theme select, streak card,
  and the celebration overlay.
- `WaffrPageHeader` / `WaffrBackHeader`: `AppShell` and nearly every
  pushed screen (settings, notifications, smart analysis, login flows).
- `ProfileAvatar`: profile, settings and account screens.
- `StreakCelebrationOverlay`: `AppShell`, when `UsageStreakService.takeIncrease()`
  reports a streak that grew on this open.

Conventions:

- Pushed screens use `WaffrBackHeader` rather than building a header by
  hand, so every screen's top bar matches.
- Colors come from `AppPalette`, timings from `AppMotion`; the celebration
  settles immediately with reduced motion and removes itself when done, so
  it never stays over the home screen.
