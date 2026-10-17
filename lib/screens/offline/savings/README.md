# Savings tab

The savings tab of the app shell (`SavingsScreen`, tab 2). One Dart library
split into part files: `savings_screen.dart` holds the imports and the
`part` directives, and the other three files start with
`part of 'savings_screen.dart'`, so their private widgets are visible to the
screen. Import only `savings_screen.dart`.

| File | What it holds |
| --- | --- |
| `savings_screen.dart` | `SavingsScreen`: range chips, period pager, layout, sheet launches. |
| `savings_period_card.dart` | `_PeriodSavingsCard` (net saved per period with % change), `_PeriodArrow`, `_SplitActionRow`. |
| `savings_goals_panel.dart` | `_ActiveGoalsPanel` (expandable goal list), its header, `_PlanButtonsRow`, `_GoalProgressCard`. |
| `savings_total_card.dart` | `_TotalSavingsCard` (lifetime savings) and the shared `_ActionButton`. |
| `sheets/` | The bottom sheets this screen opens; see `sheets/README.md`. |

How it connects:

- Data comes from `TransactionStore` (`savingsNetDuring`, `activeGoals`,
  `savingsBalance`, `currentSaved`, `hasActivePeriodicPlan`). On open the
  screen loads the store and runs `processDuePeriods()`. It rebuilds through
  `ActiveListenableBuilder`, so a hidden tab does not rebuild.
- `PinnedPeriodScrollView` (from `widgets/containers`) gives the pinned range
  selector; `CalendarPeriod.forRange(range, offset)` maps a pager page to a
  period (page 0 = current, up to 240 back).
- The screen opens the sheets: plans and completed goals from the plan row,
  manage / create from the goals panel, manual save / withdraw beside the
  total, and the shopping list through `ShoppingListPreviewCard`.
- `SmartAnalysisButton` with `InsightScope.savings` sits in the action row.

Conventions: the screen is kept alive across tab switches
(`AutomaticKeepAliveClientMixin`); spacing between cards uses `kCardGap`
from the shell.
