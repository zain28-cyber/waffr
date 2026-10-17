# lib/screens/shell

The signed-in app frame. `main.dart` shows `AppShell` once the login, theme
and lock gates are passed. Every tab lives inside it.

| File | Contents |
| --- | --- |
| `app_shell.dart` | `AppShell`: header (settings, notification bell, wordmark), lazy tab `PageView`, floating bottom bar, streak overlay. |
| `app_shell_scope.dart` | `AppShellScope` (inherited tab switcher), `AppShellTabs` (tab indices), and the shared layout constants `kFloatingNavClearance` and `kCardGap`. |

Tabs, in page order: home, report, savings, online, profile. `_tabAt`
builds each page the first time it is visited and then caches it. Unselected
tabs keep their state, but their tickers are muted and their semantics are
excluded. A tap on a neighboring tab slides the pager. A tap on a farther tab
fades through, so the pager never builds the tabs in between.

Background work the shell owns while it is mounted:

- Every minute and on resume, `_syncFinancialEvents`: due periods
  (`TransactionStore`), recurring expenses, categories, notification
  evaluation, and the usage streak (which can trigger the streak overlay).
- Comeback reminders built from `SmartFactsLoader` / `ReminderDigest`, sent
  to `SystemNotifications`.
- Home-screen widget taps (`HomeWidget`) are routed by URI host to a tab
  and/or sheet. Smart-reminder notification taps open the smart analysis.

Settings and notifications are pushed from the header. They are not tabs.
The bell's long press mutes notifications. Pages call
`AppShellScope.selectTabOf(context, AppShellTabs.x)` to switch tabs, which
does nothing outside the shell (for example, in widget tests). Every
scrolling tab should end with `kFloatingNavClearance` of padding so its last
card can clear the floating bar.
