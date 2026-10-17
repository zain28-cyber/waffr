# lib/data/services

App-wide singletons that are not ledgers: notifications, account data on the
device, home widgets, the streak, smart switches and the online feed.

| File | Contents |
| --- | --- |
| `notification_service.dart` | `NotificationService.instance` (`ChangeNotifier`): the in-app feed, mute, and the alert engine. `ensureLoaded`, `listen`, `seedIfNeeded`, `evaluate`, `add`, `markRead`, `applyRemoteSync`. Re-exports `notification_time_group.dart`. |
| `notification_rules.dart` | `part of` the service: the private `_NotificationRules` extension, one `_evaluate*` rule per alert kind (balance, forecast, spending, goals, transfers, periods, large expenses). |
| `notification_snapshot.dart` | `part of` the service: `_NotificationSnapshot`, the last-seen ratios and ids alerts compare against. |
| `notification_time_group.dart` | `NotificationTimeGroup.from(items)`: today / yesterday / this week / per-month sections for the list. |
| `system_notifications.dart` | `SystemNotifications.instance`: OS notifications (`flutter_local_notifications`) mirroring new alerts, the evening streak reminder and comeback reminders built by `ReminderDigest`. |
| `usage_streak_service.dart` | `UsageStreakService.instance`: the daily streak in prefs (`recordToday`, `takeIncrease`, `applyRemote`, `markSynced`); rules from `core/usage/streak_math.dart`. |
| `home_widget_sync.dart` | `HomeWidgetSync.instance.start()` / `refresh()`: formats balance, bills and streak text for the native Android/iOS home widgets. |
| `backup_service.dart` | `BackupService.instance`: guest choice (`authChoiceKey`), display name, wiping data on account switch or delete, restore listeners read by `main.dart`. |
| `local_data_reset.dart` | `LocalDataReset.resetCurrentDevice()`: wipes prefs, session, OS notifications and every store cache (Privacy settings). |
| `profile_identity.dart` | `ProfileIdentity.instance`: signed-in state, name and email for the profile header. |
| `smart_settings.dart` | `SmartSettings.instance`: on/off for smart alerts and note-based category suggestions. |
| `online_feed_service.dart` | `OnlineFeedService`: static exchange-rate rows and `fetchArticles()` news from the API. |
| `legacy_profile_photo.dart` | `LegacyProfilePhoto.remove()`: deletes photos older versions saved (run from `main`). |

How it connects:

- `NotificationService` is one library split into part files; the rules and
  snapshot are private to it. It listens to `TransactionStore` (`listen` ->
  `evaluate`), alerts only when a value crosses a threshold vs the snapshot
  (so reopening never repeats), and forwards new alerts to `SystemNotifications`.
  Never call `evaluate` from `build()`.
- `main.dart` hooks `seedIfNeeded` to `TransactionStore.onHydrated`;
  `AppShell` drives `listen`, `evaluate`, `recordToday`, `HomeWidgetSync.start`
  and the reminders on launch and resume.
- `UsageStreakService` and `NotificationService` sync through `core/sync`
  (settings payload and the `notifications` collection).
