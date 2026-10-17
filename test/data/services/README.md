# test/data/services

Services that are pure or prefs-based: `NotificationService` (alert rules
via `evaluate()`, the feed, mute, sync), `NotificationTimeGroup`,
`SmartSettings`, `UsageStreakService`, `ProfileIdentity`, `BackupService`,
`LocalDataReset`, `HomeWidgetSync` (data building, and `refresh()` through
a mocked `home_widget` channel), `SystemNotifications` (scheduling math,
safe without the plugin), `OnlineFeedService` rate rows and
`LegacyProfilePhoto`.

Secure storage is mocked by `setUpStores()`. Nothing reaches the network.

```
flutter test --no-pub test/data/services
```
