# sql

SQL that is run by hand against the production database. The API never runs
these files; its own schema changes happen at startup in
`database.create_tables`.

| File | Purpose |
| --- | --- |
| `admin_readonly.sql` | Creates the `admin_view` schema and the `waffr_admin` login for pgAdmin: account details and money figures only, no notes, names, settings or password hashes. |

## admin_readonly.sql

Run it once in pgAdmin's Query Tool while connected as the main database user
(the role the API uses). Replace `CHANGE_ME` with a strong password first and
do not commit the real one. Re-running it is safe; it refreshes the views.

The views run with their owner's rights, and `row_security.py` gives the
`waffr_admin` role a read policy on every owned table, so the views work
with row security on. Connected as the API's own role, the tables look empty
until you run `SET app.system = 'on';` in that session.

If you add a column the admin should see, add it to the view here; if you add
a table, also give it a policy in `row_security.py` (startup refuses tables
without one).
