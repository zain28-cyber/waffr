# test/data/stores

The prefs-backed stores. `TransactionStore` is split by its part files:
queries, cycle, income, entries, goals, periods (end-of-period leftovers
and periodic deductions), persistence (round trips and migrations) and
sync. The other files cover `CategoryStore`, `CurrencyStore`,
`ExpensePresetStore`, `RecurringExpenseStore` and `ShoppingListStore`.

Each test calls `setUpStores()`; persistence is checked by calling
`resetStoreCaches()` and loading again. Store methods use the real clock,
so dates are built relative to `DateTime.now()`.

```
flutter test --no-pub test/data/stores
```
