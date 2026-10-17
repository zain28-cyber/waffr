# lib/screens/offline

Screens that work without the network. They read and write local stores and
sync in the background when the user is signed in.

| Path | Contents |
| --- | --- |
| `home/` | Home tab (`HomeScreen`): balance, add income/expense sheets, spending distribution, recent expenses, savings goals. |
| `report/` | Report tab (`ReportScreen`): period chart, category split, comparison, transaction history and export. |
| `savings/` | Savings tab (`SavingsScreen`): net-saved period card, total, goals, and the save/withdraw/shopping/periodic sheets. |
| `profile/` | Profile tab (`ProfileScreen`): identity, usage streak and stats, wallet backdrop. |
| `notifications/` | `NotificationsScreen`, pushed from the shell header's bell. |
| `settings/` | `SettingsScreen` stack, pushed from the shell header: account, income, currencies, privacy, help. |
| `obligations/` | Recurring-expense (obligation) sheets: list, details, and charges due for approval. |
| `smart/` | Smart analysis screen (`openSmartAnalysis`): findings with their numbers and actions. |
| `login/` | Login, signup flow, password reset, guest choice. The first gate in `main.dart`. |
| `user_info/` | Profile form used as step 0 of signup, plus the country picker sheet. |
| `applock/` | `LockScreen`, the device-auth app lock shown by `main.dart`. |
| `placeholder/` | `PlaceholderScreen`, a keep-alive stub page. |
| `theme_select_screen.dart` | `ThemeSelectScreen`, the first-launch light/dark picker with live previews. |

The gate order in `main.dart` is login, then theme select (first launch
only), then lock (when enabled), then `AppShell` from `../shell/`.
