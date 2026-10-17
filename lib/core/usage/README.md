# lib/core/usage

Pure, testable rules for the daily-use streak and "how long you have used
Waffr". No prefs, no stores, no widgets.

| File | Contents |
| --- | --- |
| `streak_math.dart` | `StreakSnapshot` (count, last day, start date; `dayKey` / `parseDayKey` for the server's `YYYY-MM-DD`) and `StreakMath` (`currentCount`, `record`, `merge`, `differs`). Also `nextStreakMilestone(count)`. |
| `usage_duration.dart` | `usageDurationText(start, now)`: Arabic text such as "اليوم", days, months and days, or years and months (30-day months). |

Who uses them:

- `data/services/usage_streak_service.dart` stores the streak and calls
  `StreakMath.record` on app open and `StreakMath.merge` when a synced
  copy arrives (via `ProfileSync` in settings sync).
- `data/services/home_widget_sync.dart` shows the streak on home widgets.
- `screens/offline/profile/` (`streak_card.dart`, `profile_screen.dart`)
  shows the count, the next milestone and the usage duration.

Rules worth knowing:

- Days are local calendar days. A day counts once; missing a whole calendar
  day breaks the streak (`currentCount` returns 0 before today is recorded),
  and the next open restarts it at 1.
- `merge` keeps the further last day, so a fresh local "day 1" on a new
  device does not wipe an account streak whose last day was yesterday.
