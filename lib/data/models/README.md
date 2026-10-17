# lib/data/models

Plain records and fixed catalogs. Models own their prefs JSON form
(`toJson` / `encode` / static `decode`, returning null on bad input) and
some own their `/sync` row form. No `SharedPreferences`, no stores, no
widgets; `expense_categories.dart` uses `IconData`/`Color`, and
`nearby_place_category.dart` also launches a maps search.

| File | Contents |
| --- | --- |
| `transaction.dart` | `WaffrTransaction`: one income, expense or savings transfer; `TransactionType`, `RecurringFrequency`, `SavingsTransferKind`. |
| `savings_goal.dart` | `SavingsGoal` (target, currency, priority, periodic plan) and `GoalDurationPreset`. |
| `calendar_period.dart` | `CalendarPeriod` (start/end windows, `w:`/`m:` period keys, Saturday weeks, Levantine month names) and `SavingsRange`. |
| `currency.dart` | `CurrencyInfo`, the `Currencies` catalog, `defaultCurrencyCode` (`SYP`, always enabled). |
| `expense_categories.dart` | Built-in `expenseCategories`, custom icon/color palettes, `paymentMethods`, `categoryFor(label)` and the `customCategoryLookup` hook. |
| `custom_category_entry.dart` | `CustomCategoryEntry`: a user category with a stable id, label, icon and color slot; prefs and `/sync` forms, `legacyId()` for old label-only rows. |
| `expense_preset.dart` | `ExpensePreset`: a saved expense reused from the star on the expense sheet (amount, ×multiplier, optional recurrence). |
| `recurring_expense.dart` | `RecurringExpense` (`nextDueAt`, `requiresConfirmation`, `monthlyEquivalent`) and `RecurringUnit`. |
| `shopping_item.dart` | `ShoppingItem`: one shopping-list row; `expenseId` links a purchase to its expense; prefs and `/sync` forms. |
| `app_notification.dart` | `AppNotification`, `NotificationType`, `NotificationPriority`, `NotificationThresholds`. |
| `registration_profile.dart` | `RegistrationProfile` (sign-up fields) and validators (`registrationProfileError`, `normalizePhoneNumber`, `isValidBirthDate`). |
| `country.dart` | `CountryInfo` and `Countries` (Arabic names, calling codes; Arab countries first). |
| `exchange_rate.dart` | `ExchangeRate`: one row of the online tab's rate list. |
| `news_article.dart` | `NewsArticle`: one item from the economic news feed. |
| `nearby_place_category.dart` | `nearbyPlaceCategories` chips and `openNearbyPlaceSearch()` (Google Maps). |

Conventions:

- Records carry `updatedAt` (UTC) for last-write-wins sync; helpers from
  `core/sync/sync_clock.dart` (and `sync_mapper.dart` for shopping items)
  are the only `core` imports allowed here.
- Ids are client-generated and double as the server `client_id`.
- `categoryFor(label)` resolves built-ins first, then custom categories via
  `customCategoryLookup`, which `CategoryStore` sets when it loads.
- Stores own the lists; `CurrencyStore`, `CategoryStore` and
  `ShoppingListStore` re-export their models.
