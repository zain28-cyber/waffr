# lib/core/prefs

| File | Contents |
| --- | --- |
| `app_prefs.dart` | `AppPrefs`: one cached `SharedPreferences` for the whole app. Entry points: `AppPrefs.warmUp()`, `AppPrefs.instance` (future), `AppPrefs.cached` (sync, may be null). |

How it is used:

- `main()` awaits `AppPrefs.warmUp()` before `runApp`. After that,
  `AppPrefs.cached` is non-null, which lets `WafarApp` and
  `AppFlowController` pick the theme and the first gate synchronously.
- Every store, service and sync helper reads and writes through
  `await AppPrefs.instance` instead of calling
  `SharedPreferences.getInstance()` itself. Concurrent first calls share one
  load future.
- Widgets that need a flag during `build` (for example the smart button's
  "seen" flag) read `AppPrefs.cached` and fall back to a default.

Conventions:

- Prefs are the on-device source of truth for the ledger and settings
  (stored as JSON strings). Secrets do not go here: the JWT and the data key
  live in `flutter_secure_storage` (see `core/sync/auth_session.dart` and
  `core/security/data_key.dart`).
- Sync-related keys use the `waffer_` prefix (`waffer_sync_dirty`,
  `waffer_last_sync_at`, ...). Keys that must survive a data wipe are listed
  in `BackupService._localOnlyKeys`.
