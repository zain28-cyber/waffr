# Waffr API

The server side of Waffr: a FastAPI app on Postgres that stores each user's
ledger, keeps their devices in sync, and serves a small economic news feed.
The Flutter app works offline first and talks to it mainly through
`POST /sync`; the REST routes cover the same data row by row.

It runs on Render (`render.yaml` at the repository root): one web service
started with `uvicorn main:app` from this folder, and one Postgres database.

## Layout

| Path | What it holds |
| --- | --- |
| `main.py` | The app: startup, middleware, routers, and every `/auth` route (sign-up, sign-in, data key, password change and reset, account deletion). Importing it creates the tables. |
| `routers/` | One module per resource, plus `sync.py`. See [routers/README.md](routers/README.md). |
| `auth.py` | Password hashing (Argon2), JWT access tokens, and `get_current_user`, the dependency every signed-in route uses. |
| `database.py` | Engine, `SessionLocal`, the column mixins (`TimestampMixin`, `ClientIdMixin`, `SoftDeleteMixin`), and the startup migrations in `create_tables`. |
| `row_security.py` | Postgres row level security: the policies, and `bind_user` / `bind_system` / `system_scope`, which set who a session acts as. |
| `models.py`, `transaction_model.py`, `goal_model.py`, `shopping_model.py`, `category_model.py`, `preset_model.py`, `online_model.py` | SQLAlchemy models, one file per area. |
| `schemas.py` | Bodies of the `/auth` routes. |
| `api_schemas.py` | Bodies of the REST routes. |
| `sync_schemas.py` | Bodies of `POST /sync`. |
| `input_rules.py` | `CleanModel` (strips control characters from every request body) and the numeric limits. |
| `crud_utils.py` | Helpers the routers share: normalizing input, ownership checks, idempotent creates. |
| `password_reset.py` | Six-digit email codes for a forgotten password, sent over SMTP. |
| `rate_limit.py` | In-memory rate limits: a global one per account or IP, and tighter ones per route. |
| `security_middleware.py` | Security headers, request size limits, optional CORS, API docs switch. |
| `security_log.py`, `client_address.py` | JSON security events on the `waffr.security` logger, and the caller's IP. |
| `news_service.py` | Fetches the SANA and Al-Ikhbariya RSS feeds, keeps the economy stories, stores the newest 60. |
| `legacy_photo.py` | Leftovers of the removed profile photo feature, for older app versions. |
| `sql/` | SQL run by hand against the production database. See [sql/README.md](sql/README.md). |
| `tests/` | The pytest suite. See [tests/README.md](tests/README.md). |
| `requirements.txt`, `requirements-dev.txt` | Runtime dependencies; the dev file adds pytest and httpx. |
| `pytest.ini` | Makes this folder the pytest rootdir. |

### How a request flows

1. `security_middleware` refuses oversized bodies (256 KB, or 25 MB for a
   signed-in `/sync`) and adds the security headers.
2. `RateLimitMiddleware` counts the request per account (valid token) or per
   IP address.
3. The route runs. `get_current_user` checks the token and calls
   `bind_user`, so every later query in that request's session sees only that
   user's rows: Postgres enforces it even when a query forgets its
   `user_id` filter.
4. Deleted rows are soft-deleted (`deleted_at`), so other devices learn of the
   delete on their next sync. Their private text is blanked.

Private text (notes, categories, goal names and the like, listed in
`database.PRIVATE_TEXT_COLUMNS`) arrives already encrypted by the app with a
key the server never sees. The server stores it as it comes.

## Configuration

Read from the environment, or from `backend/.env` locally (`python-dotenv`;
real environment variables win).

| Variable | Required | Meaning |
| --- | --- | --- |
| `DATABASE_URL` | yes | Postgres URL. `postgres://` and `postgresql://` are both accepted; the psycopg driver is added. |
| `SECRET_KEY` | yes in production | Signs the tokens; 32+ random characters. Without it a random key is used and every sign-in ends on restart. Render generates it. |
| `SMTP_HOST`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM` | for password reset | Without all four, `/auth/password/forgot` answers 503. |
| `SMTP_PORT` | no | Default 587 (STARTTLS); 465 uses SSL. |
| `TRUST_PROXY_HEADERS` | no | `1` to take the client IP from `X-Forwarded-For`. Defaults to on when `RENDER=true`, off otherwise. |
| `RENDER` | set by Render | See above. |
| `CORS_ORIGINS` | no | Comma-separated origins for a web build. The phone app needs none. |
| `ENABLE_API_DOCS` | no | `1` turns on `/docs`, `/redoc` and `/openapi.json` (off by default). |

The database role the API connects as must be neither a superuser nor
`BYPASSRLS`, or row security does nothing (startup logs a warning). It should
own the tables: the policies are installed with `FORCE ROW LEVEL SECURITY`,
so they bind the owner too.

## Running locally

From the repository root, with Postgres 16 running:

```sh
# A role the policies apply to, and its database.
psql -U postgres -c "CREATE ROLE waffer_user LOGIN PASSWORD 'waffer_user' NOSUPERUSER NOBYPASSRLS"
psql -U postgres -c "CREATE DATABASE waffer OWNER waffer_user"

python -m venv .venv
. .venv/bin/activate
pip install -r backend/requirements.txt

cat > backend/.env <<'EOF'
DATABASE_URL=postgresql://waffer_user:waffer_user@localhost:5432/waffer
SECRET_KEY=change-me-to-a-long-random-value-of-32-chars-or-more
EOF

cd backend
uvicorn main:app --reload
```

The first start creates the tables and the policies. `GET /` answers
`{"message": "Waffr API is running"}`. Startup also starts an hourly news
fetch from the two RSS feeds.

## Running the tests

The tests need a real Postgres (row level security cannot be faked). They
truncate every table between tests, so give them a throwaway database. Without
`TEST_DATABASE_URL` every test is skipped.

The role in `TEST_DATABASE_URL` must:

- not be a superuser and not have `BYPASSRLS`, or the row security tests fail;
- own the test database, so it can create the tables, install the policies and
  `TRUNCATE` between tests.

A throwaway cluster on a spare port (the binaries are in
`/usr/lib/postgresql/16/bin` on Debian and Ubuntu; Postgres refuses to run as
root, so as root prefix the `initdb` and `pg_ctl` lines with
`su postgres -c '...'` and use a directory the `postgres` user owns):

```sh
PGDIR=/var/lib/postgresql/waffr-test-pg      # any empty directory you own
PG=/usr/lib/postgresql/16/bin

$PG/initdb -D "$PGDIR/data" -U postgres --auth=trust -E UTF8
$PG/pg_ctl -D "$PGDIR/data" -l "$PGDIR/server.log" \
    -o "-p 54329 -k $PGDIR -c listen_addresses=127.0.0.1" start

psql -h 127.0.0.1 -p 54329 -U postgres \
    -c "CREATE ROLE waffer_test LOGIN PASSWORD 'waffer_test' NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE" \
    -c "CREATE DATABASE waffer_test OWNER waffer_test"
```

Then, from the repository root:

```sh
python -m venv .venv && . .venv/bin/activate
pip install -r backend/requirements-dev.txt

export TEST_DATABASE_URL=postgresql://waffer_test:waffer_test@127.0.0.1:54329/waffer_test
python -m pytest backend/tests          # or: cd backend && python -m pytest
```

Stop the cluster with `$PG/pg_ctl -D "$PGDIR/data" stop` and start it again
with the same `start` line; delete `$PGDIR` to throw it away.

The suite takes about two minutes, mostly password hashing. Nothing in it
touches the network: email sending and the news feeds are faked, and Python
sockets are blocked (Postgres is reached through libpq, which is not).
`TEST_DATABASE_URL` replaces `DATABASE_URL`, so a local `backend/.env` cannot
point the tests at a real database.

There is no CI job for the backend yet; `.github/workflows/build-apk.yml`
builds and tests only the Flutter app.

## Sync in short

`POST /sync` takes, per collection, rows to upsert and tombstones, plus an
optional settings object and the `last_sync_at` the app got from its previous
sync. It answers with every row changed since then, the full settings, and a
new `server_time` for the next call. The exact rules (last write wins on the
client's `updated_at`, tombstones, the streak merge) are in
[routers/README.md](routers/README.md) and pinned down by
`tests/test_sync_push_pull.py` and `tests/test_sync_settings.py`.

Known limitation: the pull compares the server-issued `last_sync_at` with the
stamps the devices wrote, so a row edited offline before another device's
last sync, but pushed after it, never reaches that device (see
`test_a_late_push_of_an_old_edit_reaches_a_device_that_synced_in_between`,
marked as an expected failure). Fixing it needs a server-side change stamp
column.
