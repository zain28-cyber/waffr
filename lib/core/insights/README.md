# lib/core/insights

Figures derived from the ledger for display. No widgets and no storage of
their own; they read `TransactionStore` / `CurrencyStore` or plain values.

| File | Contents |
| --- | --- |
| `profile_snapshot.dart` | `ProfileSnapshot.fromStore(store)`: record counts (every currency) and lifetime spent/saved (active currency) for the profile tiles. Also `earliestUsageDate(store)`, the fallback start date when the streak service has none. |
| `spending_improvement.dart` | `SpendingImprovement.calculate(currentTotal:, previousTotal:)`: the Reports badge ("+12.5%", "-3.0%", "-") and its Arabic sentence. A drop in spending is the positive direction. |
| [`smart/`](smart/README.md) | The on-device smart analysis: facts, rules, phrasing, reminder texts, category suggestions. |

Who uses them:

- `ProfileSnapshot` / `earliestUsageDate`: `screens/offline/profile/profile_screen.dart`
  and `data/services/usage_streak_service.dart`.
- `SpendingImprovement`: the Reports screen (`screens/offline/report/report_summary.dart`,
  a part file of `reportscreen.dart`).

Both work on one currency at a time (the active one from `CurrencyStore`);
amounts in different currencies are never added together.
