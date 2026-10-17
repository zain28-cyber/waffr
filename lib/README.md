# lib

Waffr is an offline-first, Arabic (RTL) personal finance app. Everything is
stored on the device in `SharedPreferences`; a signed-in account also syncs
to the FastAPI backend.

## Boot sequence (`main.dart`)

1. `main()` warms `AppPrefs` before `runApp`, so the first frame can read
   the theme and gate flags synchronously (no throwaway splash frame).
2. It sets `TransactionStore.instance.onHydrated` to
   `NotificationService.seedIfNeeded`, so the alert baseline is captured
   before due periods are processed.
3. `SyncService.initialize()` and `LegacyProfilePhoto.remove()` start in the
   background (`unawaited`), and the bundled font OFL licenses are registered.
4. `WafarApp` builds `MaterialApp` (Arabic locale, forced RTL,
   `WaffrMaterialLocalizations` before the global delegates, `AppTheme`
   light/dark) and owns the `ThemeMode` notifier.
5. `AppFlowController` picks the gate: splash -> login -> first-launch theme
   pick -> app lock -> `AppShell`. Once built, the shell stays mounted under
   the lock (`Offstage` + `TickerMode` off) instead of being rebuilt.
   `AppShell` then runs the store work: due periods, recurring bills,
   notification evaluation, streak and home widgets.

## Layers

| Folder | Holds |
| --- | --- |
| [`core/`](core/README.md) | Theme, prefs, l10n, utils, security, sync, insights, usage math. |
| [`data/`](data/README.md) | Models, `ChangeNotifier` stores, and services (notifications, backup, widgets). |
| [`widgets/`](widgets/README.md) | Shared UI building blocks (glass surfaces, sheets, buttons, motion). |
| [`screens/`](screens/README.md) | Feature screens, the shell and its tabs. |

Dependency direction: `screens` -> `widgets` -> `core`/`data`. `core` and
`data` depend on each other: stores use `core/sync` and `core/prefs`, while
`core/sync`, `core/insights` and `core/utils/money.dart` read the stores.
Avoid adding new imports in that direction unless needed. `data` never
imports `widgets` or `screens`. Two widgets reach into `screens`
(`pinned_period_scroll_view.dart` -> `app_shell_scope.dart`,
`smart_analysis_button.dart` -> `smart_analysis_screen.dart`).
