# lib/screens

Feature screens. There is no router package. `main.dart` picks the gate
(login, then the first-launch theme picker, then the app lock, then the
shell), `AppShell` holds the five tabs, and everything else is opened with a
`Navigator.push` or a sheet.

| Path | Contents |
| --- | --- |
| `shell/` | `AppShell`: header, lazy tab `PageView`, floating bottom bar; `AppShellScope` for switching tabs. |
| `offline/home/` | Home tab: balance, add income/expense, category distribution, recent expenses, goals. |
| `offline/report/` | Report tab: spending chart (`fl_chart`), category split, transaction history. |
| `offline/savings/` | Savings tab: goals and the save, withdraw, shopping and periodic-goal sheets. |
| `online/` | Online tab: exchange rates, nearby places, news. Signed-in users only. |
| `offline/profile/` | Profile tab: identity, usage streak, wallet backdrop. |
| `offline/notifications/` | Notification list (pushed from the header bell). |
| `offline/settings/` | Settings stack (pushed from the header): account, privacy, currencies, help. |
| `offline/obligations/` | Recurring-expense sheets. |
| `offline/smart/` | Smart analysis screen. |
| `offline/login/` | Login, signup flow, password reset, guest choice. |
| `offline/user_info/` | Profile form (signup step 0) and country picker. |
| `offline/applock/` | Device-auth lock screen. |
| `offline/placeholder/` | Keep-alive stub page. |
| `offline/theme_select_screen.dart` | First-launch light/dark choice. |

To add a tab, add a new child in `_tabAt` inside `app_shell.dart` and a new
icon and label in `_BottomNavBar`. A pushed screen does not belong in the
pager.
