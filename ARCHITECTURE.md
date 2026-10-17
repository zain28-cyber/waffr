# Waffr architecture

Waffr is an offline-first personal and family finance app. The ledger
(income, expenses, savings goals, shopping list, recurring bills) lives on
the device. A FastAPI sync path can push and merge that data when the user
is signed in. There is no Google sign-in or Drive backup; the Waffr API is
the only cloud path.

The UI is Arabic, right-to-left, with a light and a dark theme. Color values
live only in `lib/core/theme/app_color.dart`.

## Folder map

```
lib/
  main.dart                 startup, theme, and which gate to show
  core/                     theme, prefs cache, sync, security, small utils
  data/
    models/                 plain types and catalogs (no I/O)
    stores/                 in-memory ledger backed by SharedPreferences
    services/               notifications, online feed, local account data
  screens/                  one folder per feature; routes stay here
  widgets/                  shared controls used by more than one screen
```

`lib/screens` is organized by feature, not by layer. A screen may own its
sheets. Shared sheet pieces (glass body, amount field, save button) live in
`lib/widgets`.

Every folder under `lib/`, `test/` and `backend/` has a README.md that lists
its files and how they connect; start there when a folder is new to you.

### Large libraries are split into part files

Big screens and classes are one Dart library spread over several files in
the same folder (`part` / `part of`), so private names stay private and every
import path keeps working. Import the root file only:

| Import | Its part files |
| --- | --- |
| `data/stores/transaction_store.dart` | `transaction_store_{queries,cycle,income,entries,goals,periods,persistence,sync}.dart`, each an extension on `TransactionStore` |
| `data/services/notification_service.dart` | `notification_rules.dart`, `notification_snapshot.dart` |
| `screens/offline/report/reportscreen.dart` | `report_{data,chart,summary}.dart`, `transaction_history_{screen,dialogs,rows}.dart` |
| `screens/offline/home/dashboard.dart` | `dashboard_{balance_card,distribution,savings_goals,expenses,sections}.dart` |
| `screens/offline/settings/privacy_security_screen.dart` | `privacy_detail_pages.dart`, `privacy_widgets.dart` |
| `screens/online/online_screen.dart` | `online_{exchange_rates,news,cards}.dart` |
| `screens/offline/savings/savings_screen.dart` | `savings_{period_card,goals_panel,total_card}.dart` |
| `screens/offline/smart/smart_analysis_screen.dart` | `smart_analysis_{thinking,cards}.dart` |
| `screens/offline/obligations/obligations_sheet.dart` | `obligation_labels.dart`, `obligation_details_sheet.dart`, `due_obligations_sheet.dart` |
| `screens/offline/home/sheets/add_expense_sheet.dart` | `expense_category_grid.dart` |

Other splits are separate libraries re-exported by the original file:
`widgets/containers/glass_sheet.dart` exports `sheet_fields`,
`sheet_amount_field`, `sheet_transitions` and `sheet_buttons`, and the
insight engine delegates to `insight_phrasing`, `report_insights`,
`savings_insights`, `profile_insights` and `insight_summary`.

## Where do I find X?

| I want to… | Look in |
| --- | --- |
| Add a new screen | `lib/screens/`. Wire it from `lib/main.dart` if it is a startup gate, or from `lib/screens/shell/app_shell.dart` if it is a tab. Settings screens are pushed from `lib/screens/offline/settings/settings_screen.dart`. |
| Change the bottom bar | `lib/screens/shell/app_shell.dart`. Five tabs, built lazily. Settings is not a tab. |
| Change colors or type | `lib/core/theme/app_color.dart` and `lib/core/theme/app_theme.dart`. `AppPalette` only picks the existing light or dark token. |
| Glass cards and buttons | `lib/widgets/containers/glass.dart` and `lib/widgets/button/glass_button.dart`. They are translucent fills, not backdrop blurs. |
| Bottom sheet chrome | `lib/widgets/containers/glass_sheet.dart` (sheet route, body, header) and the files it re-exports: `sheet_fields.dart`, `sheet_amount_field.dart`, `sheet_transitions.dart`, `sheet_buttons.dart`. |
| Motion and haptics | `lib/core/theme/app_motion.dart`: duration and curve tokens, reduced-motion handling (`AppMotion.of`; `AppMotion.sizeOf` for `AnimatedSize`, which must never get `Duration.zero`), and `AppHaptics`. Shared animated widgets live in `lib/widgets/motion/`. |
| Smart analysis | `lib/core/insights/smart/`: `SmartFacts` (numbers), `InsightEngine` (orchestrates the rule files `report_insights`, `savings_insights`, `profile_insights`; wording helpers in `insight_phrasing`), `arabic_text.dart` (grammar helpers), `category_suggester.dart` (note → category). Runs on the device only. UI: `lib/screens/offline/smart/smart_analysis_screen.dart` and `lib/widgets/smart/`. Switches: `lib/data/services/smart_settings.dart`. |
| Home screen widgets | Data: `lib/data/services/home_widget_sync.dart`. Android: `android/app/src/main/kotlin/com/waffr/app/widgets/` and `res/layout/widget_*.xml`. iOS: `ios/WaffrWidgets/` (needs a one-time Xcode target, see its README). Taps open `waffr://` links handled in `app_shell.dart`. The widgets copy the app's look (colors, glass card, Tajawal/Outfit, progress pills), so a change to `app_color.dart` also goes into `res/values*/widget_colors.xml` and the `Palette` in `WaffrWidgets.swift`. |
| Money formatting and the active currency symbol | `lib/core/utils/money.dart`. |
| The currency list and the active currency | Catalog: `lib/data/models/currency.dart`. Saved selection: `lib/data/stores/currency_store.dart`. |
| Transactions, balance, savings goals | `lib/data/models/transaction.dart`, `lib/data/models/savings_goal.dart`, and `lib/data/stores/transaction_store.dart`. |
| Expense categories | `lib/data/models/expense_categories.dart` (built-ins and chart colors) and `lib/data/stores/category_store.dart` (custom categories, removed built-ins, archive of removed ones so old expenses keep their icon). |
| Saved expenses (star on the expense sheet) | `lib/data/models/expense_preset.dart`, `lib/data/stores/expense_preset_store.dart`, `lib/screens/offline/home/sheets/expense_presets_dialog.dart`. Synced as `expense_presets`. |
| Date pickers and typed dates | `lib/widgets/dialogs/waffr_date_picker.dart` and `lib/core/utils/date_input.dart`. Arabic picker text with 0-9 digits comes from `lib/core/l10n/waffr_material_localizations.dart`. |
| Streak | `lib/core/usage/streak_math.dart`, `lib/data/services/usage_streak_service.dart`, the profile card `lib/screens/offline/profile/streak_card.dart`, and the launch overlay `lib/widgets/brand/streak_celebration.dart` (shown from `app_shell.dart`). |
| Countries and calling codes | `lib/data/models/country.dart`, picked in `lib/screens/offline/user_info/country_picker_sheet.dart`. |
| Shopping list and recurring bills | `lib/data/stores/shopping_list_store.dart`, `lib/data/stores/recurring_expense_store.dart`. |
| Spending chart | `lib/screens/offline/report/report_chart.dart` (`fl_chart` line chart; period math in `report_data.dart`). The home donut is `_DistributionChart` in `lib/screens/offline/home/dashboard_distribution.dart`. Slice colors come from `expense_categories.dart`. |
| Expense history export (PDF / text) | `lib/screens/offline/report/expense_history_share.dart`; the PDF is laid out off the UI isolate in `expense_history_pdf.dart`. |
| Exchange rates, news, nearby places | Rates and news: `lib/data/services/online_feed_service.dart`, drawn by `lib/screens/online/online_screen.dart` (guests see a sign-in cover instead). Nearby places: `lib/data/models/nearby_place_category.dart` (opens a maps search). |
| Notifications | `lib/data/services/notification_service.dart` (rules in `notification_rules.dart`) and `lib/screens/offline/notifications/notifications_screen.dart`. |
| Sign-in and cloud sync | `lib/core/sync/` (`auth_session.dart`, `sync_service.dart`). Login UI: `lib/screens/offline/login/`. |
| App lock | `lib/core/security/app_lock.dart` and `lib/screens/offline/applock/applockscreen.dart`. |
| Encryption of synced private text | `lib/core/security/data_key.dart` (data key, wrapped with the password) and `lib/core/sync/sync_crypto.dart` (which fields are sealed). Amounts, dates and the profile stay readable on the server. A forgotten password cannot recover the sealed text. |
| API security (row level security, rate limits, headers, lockout, security logs) | [SECURITY.md](SECURITY.md). Code: `backend/row_security.py`, `backend/rate_limit.py`, `backend/security_middleware.py`, `backend/security_log.py`. Tests: `backend/tests/`. |
| Profile icon (no photos: crossed out for guests, plain when signed in) | `lib/widgets/brand/profile_avatar.dart`. |
| Profile wallet backdrop (its smile follows the health score) | `lib/screens/offline/profile/wallet_backdrop.dart`. The wallet is `assets/brand/waffr_logo_backdrop.png` (the logo's green strokes without the mouth, blurred, top faded); the mouth is a vector path with one pose per `HealthBand`. |
| Local account data (guest, display name, wipe on delete/switch) | `lib/data/services/backup_service.dart`. |
| On-device preferences | `lib/core/prefs/app_prefs.dart`. Call `AppPrefs.instance` instead of `SharedPreferences.getInstance()`. |

## Startup

`main` warms the preferences cache, then runs `WafarApp`. `AppFlowController`
shows one of: login, first-launch theme, biometric lock, or `AppShell`.

## Tabs

`AppShell` is a `PageView` with a custom bar under it:

1. Home
2. Report
3. Savings
4. Online (signed-in users only; guests see a sign-in cover)
5. Profile (streak, usage)

Only the visible page is mounted (`scrollCacheExtent` is zero). The first
visit builds that tab; `AutomaticKeepAliveClientMixin` on each tab keeps it
after that, so scroll position is not lost. Swiping and tapping both move
the pager.

## Data flow

Stores are singletons (`TransactionStore.instance` and the others). They
load from preferences once, keep the list in memory, and notify listeners.
Screens use `AnimatedBuilder` / `Listenable` on those stores. They should
not read preferences again during `build`.

Expensive derived values (balance per currency, max balance, preferred
income frequency, per-period savings sums) are cached in the store and
dropped on every change. Lists are handed out as `UnmodifiableListView`.

## Sync

`SyncService` (in `lib/core/sync/`) runs one sync at a time:

1. `buildSyncRequest` collects every collection from the stores, plus
   pending tombstones and the settings payload.
2. `encodeSyncRequestInBackground` seals private text (data key) and
   encodes JSON in a background isolate (`compute`), then drops rows the
   server already has (see below).
3. The response is decoded and opened in a background isolate too, then
   `applySyncResponse` merges it into the stores. Tombstones are cleared
   only for ids that were actually sent or echoed back.
4. `SyncDirty` keeps a revision counter, so an edit made while a sync is in
   flight keeps the device dirty for the next round.

**Incremental push.** After each successful sync the device remembers a
fingerprint of every row it sent (`sync_sent_rows.dart`, in memory). The
next push leaves out rows whose fingerprint did not change. A full push
(every row) still happens on sign-in, on a forced sync, on the first sync
after launch and after a currency upgrade; rows with a pending tombstone are
always sent. Filtering by `updated_at` instead was rejected: row times come
from the device clock (and some are back-dated event times), while the
server's `last_sync_at` comes from the server clock, so a skewed clock would
silently skip rows. Fingerprints only depend on the row content.

Tombstones in `lib/core/sync/sync_tombstones.dart` stop a deleted row from
coming back. The server side (`backend/routers/sync.py`) merges per row by
`updated_at` and merges settings field by field; streak history is merged
by day. See [backend/README.md](backend/README.md).

## Tests

- `test/` mirrors `lib/`: `test/core/...`, `test/data/...` hold unit tests;
  `test/screens/...` and `test/widgets/...` hold widget tests.
- `test/helpers/store_harness.dart` (`setUpStores`) gives each test an empty
  device: mock SharedPreferences and secure storage and every store's
  `resetCache()`.
- `test/helpers/widget_harness.dart` (`smokeTestScreen`) pumps a screen with
  the app's theme, Arabic locale and RTL direction on a 390x844 phone view,
  in light and dark, empty and with sample data, and once with reduced
  motion, and fails on any exception or layout overflow. Platform channels
  are answered with harmless defaults.
- `test/widget_test.dart` boots the whole app (`WafarApp`).
- Backend: `backend/tests/` (pytest against a throwaway Postgres; see
  [backend/README.md](backend/README.md)).

Run everything with `flutter analyze`, `flutter test`, and
`python -m pytest backend/tests`.

## More detail

- [lib/core/README.md](lib/core/README.md)
- [lib/data/README.md](lib/data/README.md)
- [lib/screens/README.md](lib/screens/README.md)
- [lib/widgets/README.md](lib/widgets/README.md)
- [test/README.md](test/README.md)
- [backend/README.md](backend/README.md)
