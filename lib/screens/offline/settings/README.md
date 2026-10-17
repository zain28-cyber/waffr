# Settings

The settings page and the pages it pushes. `SettingsScreen` is pushed from
the app shell with the theme notifier, the theme toggle, and the root
`AppFlowController` state (typed `dynamic`, may be null), which pages use to
refresh the app lock and to return to login after signing out.

| File | Main entry point | What it is |
| --- | --- | --- |
| `settings_screen.dart` | `SettingsScreen` | Hub: account card, income, currencies, obligations, dark mode, language, app lock, smart analysis, privacy, help, guest reset. |
| `account_screen.dart` | `AccountScreen` | Signed-in account: display name, email, change password, sign out, delete account. |
| `change_password_screen.dart` | `ChangePasswordScreen` | Current / new / confirm password form (`AuthSession.changePassword`). |
| `ai_permissions_screen.dart` | `AIPermissionsScreen` | Smart analysis shortcut and the `SmartSettings` switches. |
| `privacy_security_screen.dart` | `PrivacySecurityScreen` | Privacy hub with rows that open the detail pages. |
| `privacy_detail_pages.dart` | (part file) | Account data, cloud sync, synced data, app lock and local reset pages. |
| `privacy_widgets.dart` | (part file) | Shared scaffold, colors, rows, banner and info lines for the privacy pages. |
| `privacy_info_screen.dart` | `PrivacyInfoScreen` | Static privacy copy. Not linked from any screen; only the smoke test opens it. |
| `help_screen.dart` | `HelpScreen` | FAQ; the Q&A copy is a const list inside `build`. |
| `sheets/` | | Currencies and income sheets; see `sheets/README.md`. |

How it connects:

- Signed-in users open `AccountScreen`; guests are sent to `LoginScreen`
  and synced afterwards. Settings reloads its summary whenever a pushed page
  returns.
- Income is edited with `showMonthlyIncomeSheet` and saved through
  `TransactionStore.setPreferredIncomeAmount` / `clearPreferredIncomeAmount`.
- App lock: settings uses `local_auth` directly and the prefs key
  `app_lock`; the privacy app-lock page goes through `AppLock.setEnabled`.
- Guest reset (settings) clears prefs, the session and every store cache;
  the privacy page's reset calls `LocalDataReset.resetCurrentDevice`.

Conventions: `privacy_security_screen.dart` is one library with two part
files; import only that file. The weekly income tile is hidden by
`_weeklyIncomeChoiceEnabled`. The About tile has no action yet.
