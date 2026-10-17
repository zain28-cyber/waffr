# routers

One `APIRouter` per resource. `main.py` includes them all; the `/auth` routes
live in `main.py` itself.

| Module | Prefix | Model(s) | Bodies |
| --- | --- | --- | --- |
| `transactions.py` | `/transactions` | `Transaction` | `api_schemas.Transaction*` |
| `recurring.py` | `/recurring-expenses` | `RecurringExpense` | `api_schemas.RecurringExpense*` |
| `savings.py` | `/savings-goals`, `/savings-transfers` | `SavingsGoal`, `SavingsTransfer` | `api_schemas.SavingsGoal*`, `SavingsTransfer*` |
| `shopping.py` | `/shopping-lists`, `/shopping-lists/{id}/items` | `ShoppingList`, `ShoppingItem` | `api_schemas.Shopping*` |
| `notifications.py` | `/notifications` | `Notification` | `api_schemas.Notification*` |
| `settings.py` | `/settings` | `UserSettings` | `api_schemas.UserSettings*` |
| `online.py` | `/online/news` | `NewsArticle` (via `news_service`) | `api_schemas.News*` |
| `sync.py` | `/sync` | all of the above, plus `ExpenseCategory` and `ExpensePreset` | `sync_schemas` |

Expense categories and presets have no REST routes; they only travel through
`/sync`.

## Shared patterns

- **Signed in.** Every route except `GET /online/news` depends on
  `auth.get_current_user`, which answers 401 without a valid token and binds
  the session to the user for row security.
- **Ownership.** Rows are looked up with the user's id (`owned_or_404`,
  `find_by_client_id`); another user's row is a 404, never a 403.
- **Idempotent creates.** A `POST` with a `client_id` the user already has
  returns the stored row instead of a duplicate (`commit_or_existing` also
  covers two requests racing). Transactions also dedupe on `source_id`,
  notifications on `event_key`.
- **Soft deletes.** `DELETE` sets `deleted_at` and `updated_at`; lists hide the
  row and `/sync` reports it as a tombstone.
- **Partial updates.** `PATCH` changes only the fields present in the body
  (`model_dump(exclude_unset=True)`).

## Sync rules (`sync.py`)

Order inside one request, all in one transaction (any error rolls back the
whole push):

1. Upserts, parents first: goals, lists, transactions, transfers, items,
   recurring expenses, notifications, categories, presets.
2. Tombstones, children first: items, transfers, ... goals, lists.
3. Settings.
4. The reply: per collection, rows whose `updated_at` or `deleted_at` is
   after `last_sync_at` (every row when it is null), split into live upserts
   and tombstones; the full settings; `server_time`.

Rows:

- Matched by `(user_id, client_id)`; a new id creates a row. A notification
  with an unknown client id but a live `event_key` updates that notification.
- Last write wins on the client's `updated_at` (falling back to
  `occurred_at` or `created_at`, then the server's clock). Older than the
  stored row: ignored. Equal or newer: applied, and the row is live again.
- A tombstone deletes the row unless the row's `updated_at` is newer; it also
  blanks the row's private text. A later tombstone never moves `deleted_at`
  back.
- An item naming an unknown list creates that list; a transfer naming an
  unknown goal is stored without a goal.

Settings:

- Applied when their `updated_at` is equal or newer than the stored one, or
  missing. Fields left out of the object are not changed; `null` income
  amounts clear them.
- Older settings only add their `processed_period_keys`; the stored stamp
  stays as it was.
- `processed_period_keys` is always a sorted union.
- The usage streak merges by day whatever the stamps say: the later
  `streak_last_date` wins, the same day keeps the larger count, an earlier or
  invalid day is ignored. `usage_started_at` keeps the earliest valid value.

Every rule above has a test in `tests/test_sync_push_pull.py` or
`tests/test_sync_settings.py`.
