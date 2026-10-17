# test/helpers

Shared code for tests; nothing here is a library under `lib/`.

- `store_harness.dart`: `setUpStores()` gives a test an empty device
  (fresh in-memory SharedPreferences, mocked secure storage, every store's
  `resetCache()`), and `resetStoreCaches()` makes the stores re-read prefs
  after a test seeds them.
- `ledger_builders.dart`: `expenseAt`, `incomeAt`, `transferAt` and
  `buildFacts` for short, readable test data.
- `widget_harness.dart`: the widget smoke-test harness used by
  `test/screens` and `test/widgets` (owned by the widget tests).
- `store_harness_test.dart`: checks the harness itself.

```
flutter test --no-pub test/helpers
```
