# lib/data/stores

`ChangeNotifier` singletons (`XStore.instance`) that own the user's data.
Each loads from prefs once (`ensureLoaded()` returns the same future), then
serves memory and notifies listeners on every change.

| File | Contents |
| --- | --- |
| `transaction_store.dart` | `TransactionStore`: the ledger (incomes, expenses, savings transfers), balances, income settings and savings goals, per currency. Library root; declares the part files below. |
| `transaction_store_queries.dart` | `TransactionQueries`: `expenses`, `incomes`, `goals`, `balance`, `savingsBalance`, totals, `expensesByCategory`. |
| `transaction_store_cycle.dart` | `BalanceCycle`: cycle start, `cycleSpent`, `maxBalance` (the home bar's 100%), `remainingRatio`, `cycleKey`. |
| `transaction_store_income.dart` | `IncomeSettings`: `addIncome`, configured weekly/monthly income per currency, `referenceIncome`. |
| `transaction_store_entries.dart` | `LedgerEntries`: `addExpense`, `undoExpense`, `undoIncome`, `saveManually`, `withdrawFromSavings`. |
| `transaction_store_goals.dart` | `GoalPlans`: `goalProgress`, `createGoal`, `applyPeriodicPlan`, `deleteGoal`, `reorderActiveGoals`, completion. |
| `transaction_store_periods.dart` | `DuePeriods`: `processDuePeriods()` (periodic goal deductions, leftover to savings, each once by token). |
| `transaction_store_persistence.dart` | `_LedgerPersistence`: load, migrate legacy formats, save. |
| `transaction_store_sync.dart` | `LedgerSync`: `applyRemoteSync(...)`, merging the server copy. |
| `currency_store.dart` | `CurrencyStore`: enabled currencies and the active one (`activeCode`, `setActive`). Re-exports `models/currency.dart`. |
| `category_store.dart` | `CategoryStore`: custom categories, hidden built-ins (synced in settings), local archive of removed ones; sets `customCategoryLookup`. |
| `expense_preset_store.dart` | `ExpensePresetStore`: saved expenses (`add`, `remove`). |
| `shopping_list_store.dart` | `ShoppingListStore`: items; `completePurchase` records the expense through `TransactionStore`. |
| `recurring_expense_store.dart` | `RecurringExpenseStore`: recurring bills, `processDue()` catch-up that posts real expenses, confirmations and postponing. |

Conventions:

- `TransactionStore` is one class split by topic into `part` files, each a
  named extension on it. Import only `transaction_store.dart`; it brings in
  all of them. Private state and helpers are shared across the parts.
- Most getters work on the active currency (`CurrencyStore.activeCode`);
  `...For(currencyCode)` variants take one explicitly. Currencies are never mixed.
- Every local edit calls `SyncDirty.mark()`; deletes add a `SyncTombstones`
  entry. `applyRemoteSync` merges with `mergeRemoteRecords` (last write wins)
  and is called only from `core/sync/sync_apply.dart`.
- Other stores never write the ledger directly: shopping purchases and
  recurring charges go through `TransactionStore` so balances stay consistent.
- `resetCache()` drops memory so the next `ensureLoaded` re-reads prefs
  (used by account switch and data wipe).
