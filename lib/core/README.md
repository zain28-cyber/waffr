# lib/core

Shared code that is not a screen, not a widget, and not a stored record.

| Folder | What it holds |
| --- | --- |
| [`theme/`](theme/README.md) | `AppColors` tokens, `AppPalette` (light or dark tokens for the current brightness), `AppTheme` (fonts and `ThemeData`), `AppMotion` / `AppHaptics`. |
| [`prefs/`](prefs/README.md) | `AppPrefs`, the one cached `SharedPreferences` handle. Warmed in `main`. |
| [`utils/`](utils/README.md) | Money and date formatting, typed DD/MM/YYYY input, snack bars and dialogs. |
| [`l10n/`](l10n/README.md) | `WaffrMaterialLocalizations`: Arabic Material strings with 0-9 digits and Levantine month names. |
| [`security/`](security/README.md) | `AppLock` (biometric gate flag) and the account data key that encrypts private sync fields. |
| [`sync/`](sync/README.md) | FastAPI auth session, incremental push/pull, dirty flag, tombstones, profile sync. |
| [`insights/`](insights/README.md) | Profile stats, spending comparison, and the on-device smart analysis ([`insights/smart/`](insights/smart/README.md)). |
| [`usage/`](usage/README.md) | Pure streak rules and the "using Waffr for ..." duration text. |

Color values are not duplicated anywhere else on purpose. If a widget needs
"the current accent", use `AppPalette.of(context)`.

`core` is not a leaf layer: `sync/`, `insights/` and `utils/money.dart`
read the stores in `lib/data`. Pure helpers (`sync_clock`, `streak_math`,
`smart_facts`, the insight rules) take plain values so tests need no stores.
