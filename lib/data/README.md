# lib/data

Ledger types, the on-device stores, and services that talk to disk, the OS
or the network. Prefs (via `AppPrefs`) are the offline source of truth;
`core/sync` copies them to the server for signed-in users.

| Folder | What it holds |
| --- | --- |
| [`models/`](models/README.md) | Plain records and catalogs: `WaffrTransaction`, `SavingsGoal`, `CalendarPeriod`, currencies, categories (`CustomCategoryEntry`), presets, recurring bills, `ShoppingItem`, notifications, sign-up profile, online feed rows. |
| [`stores/`](stores/README.md) | `ChangeNotifier` singletons: `TransactionStore` (split into `transaction_store_*.dart` part files), `CurrencyStore`, `CategoryStore`, `ExpensePresetStore`, `ShoppingListStore`, `RecurringExpenseStore`. |
| [`services/`](services/README.md) | `NotificationService` (with part files), `SystemNotifications`, `UsageStreakService`, `HomeWidgetSync`, `BackupService`, `LocalDataReset`, `ProfileIdentity`, `SmartSettings`, `OnlineFeedService`, `LegacyProfilePhoto`. |

Dependency direction inside `data`: mostly services -> stores -> models
(exception: `RecurringExpenseStore` posts alerts through `NotificationService`). `data`
uses `core/prefs`, `core/sync` (dirty flag, tombstones, merge, mapper,
clock), `core/utils/money.dart` and a few `core/insights` helpers; it never
imports `widgets` or `screens`.

Rules for new code:

- Load with `await XStore.instance.ensureLoaded()`, then read memory.
- After a local change, persist, call `SyncDirty.mark()`, and record deletes
  with `SyncTombstones`, so the next sync carries them.
- Only `core/sync/sync_apply.dart` calls the stores' `applyRemoteSync`.
