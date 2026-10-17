# Home tab

The home tab of the app shell (`HomeScreen`, tab 0). One Dart library split
into part files: `dashboard.dart` holds the imports and the `part`
directives, and the other `dashboard_*.dart` files start with
`part of 'dashboard.dart'`, so their private card widgets are visible to the
screen. Import only `dashboard.dart`.

| File | What it holds |
| --- | --- |
| `dashboard.dart` | `HomeScreen`: the scrollable stack of cards and what each one opens. |
| `dashboard_balance_card.dart` | `_BalanceCard` (balance, remaining-ratio bar, currency swipe and dots, income-log / shopping-list buttons), `_ActionButton` (add income / expense). |
| `dashboard_distribution.dart` | `_DistributionCard`: donut chart (fl_chart) and the top-five category legend. |
| `dashboard_expenses.dart` | `_ExpensesAndObligationsCard`: two swipeable pages, last three expenses and up to three obligations. |
| `dashboard_savings_goals.dart` | `_SavingGoalCard` (one page per active goal), `_PageDots`, vertical progress bar. |
| `dashboard_sections.dart` | Shared chrome: `_SectionCard`, `_SectionTitle`, `_EmptyState`. |
| `sheets/` | Add-expense and add-income sheets; see `sheets/README.md`. |

How it connects:

- Data comes from `TransactionStore` (balance, cycle spend, category totals,
  expenses, active goals), `RecurringExpenseStore` (obligations for the
  active currency), `CategoryStore` and `CurrencyStore`. The four are merged
  into one `ActiveListenableBuilder`, so a hidden tab does not rebuild.
- Taps: the action buttons open `showAddIncomeSheet` / `showAddExpenseSheet`;
  the balance card opens the income `TransactionHistoryScreen` and the
  shopping list sheet; the distribution card switches to the report tab and
  the goals card to the savings tab (`AppShellScope.selectTabOf`); the
  expenses card opens the expense history or `showObligationsSheet`,
  matching the visible page.
- Obligation rows reuse `obligationTitle` / `obligationStatus` /
  `obligationNeedsAttention` from `obligations/obligations_sheet.dart`.

Conventions: the screen is kept alive across tab switches
(`AutomaticKeepAliveClientMixin`); spacing uses `kCardGap` and the bottom
padding `kFloatingNavClearance` from the shell. The expenses card remembers
its last page in prefs (`home_expenses_card_page`). Inner pagers swallow
horizontal scroll notifications so the shell's tab pager does not move.

Tests: `test/screens/offline/home/dashboard_test.dart`.
