"""Postgres row level security: each account only reaches its own rows.

Every transaction carries the signed-in user's id in the ``app.user_id``
setting, and the policies compare each row's owner with it. A query that
forgets its ``user_id`` filter therefore still sees one account only, and a
write for another account is refused by the database. With no setting the
tables look empty, so a missed binding fails closed.

``app.system`` is for the server's own work: startup migrations, the news
refresh, and the lookup by email that runs before anyone is signed in.

FORCE makes the policies apply to the table owner too, which is the role the
API connects as on Render. Both settings are transaction-local
(``set_config(..., true)``), so nothing leaks to the next request through the
connection pool.

This is a second lock behind the ``user_id`` filters in the routes, not a
replacement: code that can run arbitrary SQL could set the values itself.
"""

import logging
from contextlib import contextmanager

from sqlalchemy import event, text
from sqlalchemy.exc import SQLAlchemyError

_USER_KEY = "rls_user_id"
_SYSTEM_KEY = "rls_system"

_CURRENT_USER = "NULLIF(current_setting('app.user_id', true), '')::integer"
_SYSTEM = "current_setting('app.system', true) = 'on'"
# The read-only pgAdmin login from sql/admin_readonly.sql. Its views run
# with the owner's rights, so the policies need to let it read.
_ADMIN_READ = "current_user = 'waffr_admin'"

# Tables whose rows belong to one user through user_id.
OWNED_TABLES = (
    "user_settings",
    "transactions",
    "recurring_expenses",
    "savings_goals",
    "savings_transfers",
    "shopping_lists",
    "shopping_items",
    "notifications",
    "expense_categories",
    "expense_presets",
)
# Shared feed data: anyone may read, only the server writes.
PUBLIC_READ_TABLES = ("news_articles", "exchange_rates")

# Links between a user's own rows must stay inside that account. Foreign keys
# skip row security, so the policies check them.
_EXTRA_WRITE_CHECKS = {
    "shopping_items": (
        "EXISTS (SELECT 1 FROM shopping_lists l "
        "WHERE l.id = shopping_items.list_id "
        "AND l.user_id = shopping_items.user_id)"
    ),
    "savings_transfers": (
        "(savings_transfers.goal_id IS NULL OR EXISTS ("
        "SELECT 1 FROM savings_goals g "
        "WHERE g.id = savings_transfers.goal_id "
        "AND g.user_id = savings_transfers.user_id))"
    ),
}


def _policies(table: str) -> list[tuple[str, str]]:
    """(name, CREATE POLICY body) pairs for one table."""
    system = f"FOR ALL USING ({_SYSTEM}) WITH CHECK ({_SYSTEM})"
    admin = f"FOR SELECT USING ({_ADMIN_READ})"
    if table in PUBLIC_READ_TABLES:
        return [
            ("waffr_public_read", "FOR SELECT USING (true)"),
            ("waffr_system", system),
        ]
    owner_column = "id" if table == "users" else "user_id"
    owned = f"{owner_column} = {_CURRENT_USER}"
    check = owned
    extra = _EXTRA_WRITE_CHECKS.get(table)
    if extra is not None:
        check = f"{owned} AND {extra}"
    return [
        ("waffr_owner", f"FOR ALL USING ({owned}) WITH CHECK ({check})"),
        ("waffr_system", system),
        ("waffr_admin_read", admin),
    ]


def protected_tables() -> tuple[str, ...]:
    """Every table that gets row security policies."""
    return ("users", *OWNED_TABLES, *PUBLIC_READ_TABLES)


def install(connection, model_tables) -> None:
    """Enable and force row security with fresh policies on every table.

    ``model_tables`` is every table name the models define. A table missing
    from the lists above stops startup, so a new table cannot ship without a
    policy.
    """
    missing = sorted(set(model_tables) - set(protected_tables()))
    if missing:
        raise RuntimeError(
            "Tables without a row security policy: " + ", ".join(missing)
        )
    bypasses = connection.scalar(
        text("SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname = current_user")
    )
    if bypasses:
        logging.getLogger("waffr.security").warning(
            "The database role %s bypasses row level security; connect the API "
            "with a role that is neither superuser nor BYPASSRLS",
            connection.scalar(text("SELECT current_user")),
        )
    for table in protected_tables():
        connection.execute(text(f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY"))
        connection.execute(text(f"ALTER TABLE {table} FORCE ROW LEVEL SECURITY"))
        for name, body in _policies(table):
            connection.execute(text(f"DROP POLICY IF EXISTS {name} ON {table}"))
            connection.execute(text(f"CREATE POLICY {name} ON {table} {body}"))


def _apply(connection, info: dict) -> None:
    user_id = info.get(_USER_KEY)
    system = info.get(_SYSTEM_KEY, False)
    if user_id is None and not system:
        return
    connection.execute(
        text(
            "SELECT set_config('app.user_id', :user_id, true), "
            "set_config('app.system', :system, true)"
        ),
        {
            "user_id": "" if user_id is None else str(user_id),
            "system": "on" if system else "off",
        },
    )


def attach(session_factory) -> None:
    """Re-apply the session's identity at the start of every transaction."""

    @event.listens_for(session_factory, "after_begin")
    def _after_begin(session, _transaction, connection):
        _apply(connection, session.info)


def _refresh(session) -> None:
    if session.in_transaction():
        _apply(session.connection(), session.info)


def bind_user(session, user_id: int) -> None:
    """Every later query in this session acts as [user_id] only."""
    session.info[_USER_KEY] = int(user_id)
    session.info[_SYSTEM_KEY] = False
    _refresh(session)


def bind_system(session) -> None:
    """For the server's own sessions (news refresh, background jobs)."""
    session.info[_USER_KEY] = None
    session.info[_SYSTEM_KEY] = True
    _refresh(session)


@contextmanager
def system_scope(session):
    """Briefly act as the server, e.g. to find an account by email."""
    previous = session.info.get(_SYSTEM_KEY, False)
    session.info[_SYSTEM_KEY] = True
    _apply(session.connection(), session.info)
    try:
        yield
    finally:
        session.info[_SYSTEM_KEY] = previous
        try:
            if previous:
                _apply(session.connection(), session.info)
            else:
                session.execute(text("SELECT set_config('app.system', 'off', true)"))
        except SQLAlchemyError:
            # The transaction already failed; its rollback drops the setting.
            pass
