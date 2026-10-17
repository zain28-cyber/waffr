# tests

The backend's pytest suite. It runs the real app through FastAPI's
`TestClient` against a real, throwaway Postgres; the setup (cluster, role,
`TEST_DATABASE_URL`) is in [../README.md](../README.md#running-the-tests).

```sh
TEST_DATABASE_URL=postgresql://waffer_test:waffer_test@127.0.0.1:54329/waffer_test \
    python -m pytest backend/tests
```

Without `TEST_DATABASE_URL` every test is skipped.

## Files

| File | Covers |
| --- | --- |
| `conftest.py` | Environment for the app, fixtures and helpers (below). |
| `test_auth.py` | Sign-up, sign-in, tokens (expiry, versions, forgeries), data key, password change, password reset flow, account deletion, legacy photo routes. |
| `test_api_security.py` | Cross-account isolation, lockout and throttling, rate limits, security headers, body size limits, input cleaning. |
| `test_row_security.py` | The Postgres policies themselves, queried directly without the API. |
| `test_transactions.py` | `/transactions`. |
| `test_recurring.py` | `/recurring-expenses`. |
| `test_savings.py` | `/savings-goals` and `/savings-transfers`, including the saved amount. |
| `test_shopping.py` | `/shopping-lists` and their items. |
| `test_notifications.py` | `/notifications`. |
| `test_settings.py` | `/settings`. |
| `test_online.py` | `/online/news` and `news_service`, with canned RSS. |
| `test_sync_push_pull.py` | `/sync` rows: push for every collection, pull by `last_sync_at`, last write wins, tombstones, cross-account isolation. Includes every scenario of the old live script `backend/_test_sync.py`. |
| `test_sync_settings.py` | `/sync` settings: last write wins, period key union, currency and income normalization, the usage streak merge. |

Each router file checks the happy paths, validation errors (422), another
user's rows (404) and a missing token (401) for every route.

## Fixtures and helpers (`conftest.py`)

Autouse, for every test:

- `clean_state`: truncates every table and clears the rate limiter.
- `no_network`: Python sockets refuse to connect.
- `offline_services`: email sending fails and every news feed is down,
  unless a test swaps in its own fake.

On request:

- `client`: a `TestClient` (without the lifespan, so no hourly news fetch).
- `alice`, `bob`: bearer tokens of two fresh accounts.
- `sent_codes`: captures reset emails as `{email: code}`.
- `main_module`: the imported app module.
- `news_feeds` (in `test_online.py`): serves canned feeds.

Helpers:

- `register(client, email, ...)`, `bearer(token)`.
- `sync(client, token, last_sync_at=..., settings=..., deletes={...}, transactions=[...], ...)`
  posts a sync body built by `sync_payload` and returns the 200 reply;
  `ids(...)` and `deleted_ids(...)` read client ids out of a reply collection.
- `at(minutes)` is a stamp relative to the fixed `T0` (2025-03-01 12:00 UTC),
  so sync tests never depend on the clock. `parse_time` reads stamps back.
- `system_scalar(sql)`, `system_execute(sql)` query or change the database as
  the server, past row security.

## Conventions

- One behaviour per test, named as a sentence.
- Sync tests use explicit `at(...)` stamps. Mixing them with rows created
  through REST (stamped with the real clock, in the future relative to `T0`)
  is deliberate only where a test says so.
- The sign-up limit is 10 per address per hour and the sync limit 30 per
  account per minute; the limiter is cleared before each test, so stay under
  those within one test.
- `test_a_late_push_of_an_old_edit_reaches_a_device_that_synced_in_between`
  is a strict expected failure documenting a known gap in the pull cursor.
  When the gap is fixed it starts passing, and pytest reports it until the
  marker is removed.
