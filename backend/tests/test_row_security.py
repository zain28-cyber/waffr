"""Row level security, checked straight against the database."""

from decimal import Decimal

import pytest
from sqlalchemy import func, select, text
from sqlalchemy.exc import DBAPIError


@pytest.fixture
def db(main_module):
    """A session with no user bound."""
    from database import SessionLocal

    session = SessionLocal()
    yield session
    session.rollback()
    session.close()


@pytest.fixture
def two_users(main_module):
    """Users 1 and 2, each with a transaction, a shopping list and a goal."""
    from database import SessionLocal
    from goal_model import SavingsGoal
    from models import User
    from row_security import bind_system
    from shopping_model import ShoppingList
    from transaction_model import Transaction

    session = SessionLocal()
    bind_system(session)
    ids = {}
    for number in (1, 2):
        user = User(email=f"user{number}@example.com", password_hash="x")
        session.add(user)
        session.flush()
        transaction = Transaction(user_id=user.id, type="expense", amount=Decimal("5"))
        session.add(transaction)
        shopping_list = ShoppingList(user_id=user.id, name="list")
        goal = SavingsGoal(user_id=user.id, name="goal", target_amount=Decimal("10"))
        session.add_all([shopping_list, goal])
        session.flush()
        ids[number] = {
            "user": user.id,
            "transaction": transaction.id,
            "list": shopping_list.id,
            "goal": goal.id,
        }
    session.commit()
    session.close()
    return ids


def _count(session, table: str) -> int:
    return session.scalar(text(f"SELECT count(*) FROM {table}"))


def test_every_table_has_forced_row_security(main_module):
    from database import Base, engine

    with engine.connect() as connection:
        rows = connection.execute(
            text(
                "SELECT relname, relrowsecurity, relforcerowsecurity "
                "FROM pg_class WHERE relkind = 'r' AND relnamespace = 'public'::regnamespace"
            )
        ).all()
        policies = connection.execute(
            text("SELECT tablename, count(*) FROM pg_policies GROUP BY tablename")
        ).all()
    state = {name: (enabled, forced) for name, enabled, forced in rows}
    policy_count = dict(policies)
    for table in Base.metadata.tables:
        assert state[table] == (True, True), table
        assert policy_count.get(table, 0) >= 2, table


def test_install_refuses_a_table_without_policy(main_module):
    import row_security

    with pytest.raises(RuntimeError, match="brand_new"):
        row_security.install(None, [*row_security.protected_tables(), "brand_new"])


def test_unbound_session_sees_nothing(db, two_users):
    assert _count(db, "users") == 0
    assert _count(db, "transactions") == 0
    assert _count(db, "shopping_lists") == 0


def test_user_sees_only_own_rows_even_without_a_filter(db, two_users):
    from row_security import bind_user
    from transaction_model import Transaction

    bind_user(db, two_users[1]["user"])
    owners = db.scalars(select(Transaction.user_id)).all()
    assert owners == [two_users[1]["user"]]
    assert _count(db, "users") == 1
    assert db.get(Transaction, two_users[2]["transaction"]) is None


def test_binding_survives_commit_and_switches_cleanly(db, two_users):
    from row_security import bind_user

    bind_user(db, two_users[1]["user"])
    assert _count(db, "transactions") == 1
    db.commit()
    assert _count(db, "transactions") == 1
    assert db.scalar(text("SELECT user_id FROM transactions")) == two_users[1]["user"]
    bind_user(db, two_users[2]["user"])
    assert db.scalar(text("SELECT user_id FROM transactions")) == two_users[2]["user"]


def test_cannot_write_rows_for_another_user(db, two_users):
    from row_security import bind_user
    from transaction_model import Transaction

    bind_user(db, two_users[1]["user"])
    db.add(Transaction(user_id=two_users[2]["user"], type="expense", amount=Decimal("1")))
    with pytest.raises(DBAPIError, match="row-level security"):
        db.flush()


def test_cannot_change_or_delete_another_users_rows(db, two_users):
    from row_security import bind_user

    bind_user(db, two_users[1]["user"])
    other = two_users[2]["user"]
    updated = db.execute(
        text("UPDATE transactions SET amount = 999 WHERE user_id = :u"), {"u": other}
    )
    deleted = db.execute(text("DELETE FROM users WHERE id = :u"), {"u": other})
    assert updated.rowcount == 0
    assert deleted.rowcount == 0


def test_cannot_hand_a_row_to_another_user(db, two_users):
    from row_security import bind_user

    bind_user(db, two_users[1]["user"])
    with pytest.raises(DBAPIError, match="row-level security"):
        db.execute(
            text("UPDATE transactions SET user_id = :other"),
            {"other": two_users[2]["user"]},
        )


def test_links_must_stay_inside_the_account(db, two_users):
    from goal_model import SavingsTransfer
    from row_security import bind_user
    from shopping_model import ShoppingItem

    mine, theirs = two_users[1], two_users[2]
    bind_user(db, mine["user"])
    db.add(ShoppingItem(user_id=mine["user"], list_id=theirs["list"], name="milk"))
    with pytest.raises(DBAPIError, match="row-level security"):
        db.flush()
    db.rollback()

    db.add(
        SavingsTransfer(
            user_id=mine["user"],
            goal_id=theirs["goal"],
            amount=Decimal("1"),
            direction="to_savings",
        )
    )
    with pytest.raises(DBAPIError, match="row-level security"):
        db.flush()
    db.rollback()

    db.add(ShoppingItem(user_id=mine["user"], list_id=mine["list"], name="milk"))
    db.add(
        SavingsTransfer(
            user_id=mine["user"],
            goal_id=mine["goal"],
            amount=Decimal("1"),
            direction="to_savings",
        )
    )
    db.flush()


def test_system_scope_is_brief(db, two_users):
    from row_security import bind_user, system_scope

    bind_user(db, two_users[1]["user"])
    with system_scope(db):
        assert _count(db, "users") == 2
    assert _count(db, "users") == 1


def test_nothing_leaks_through_the_connection_pool(main_module, two_users):
    from database import SessionLocal, engine
    from row_security import bind_user

    session = SessionLocal()
    bind_user(session, two_users[1]["user"])
    assert _count(session, "transactions") == 1
    session.commit()
    session.close()

    for _ in range(engine.pool.size() + 1):
        with engine.connect() as connection:
            setting = connection.scalar(text("SELECT current_setting('app.user_id', true)"))
            assert not setting
            assert connection.scalar(text("SELECT count(*) FROM transactions")) == 0


def test_news_is_public_to_read_but_only_the_server_writes(db):
    from database import SessionLocal, utc_now
    from online_model import NewsArticle
    from row_security import bind_system

    db.add(
        NewsArticle(
            title="t", source="s", url="https://sana.sy/a", guid="g", published_at=utc_now()
        )
    )
    with pytest.raises(DBAPIError, match="row-level security"):
        db.flush()
    db.rollback()

    writer = SessionLocal()
    bind_system(writer)
    writer.add(
        NewsArticle(
            title="t", source="s", url="https://sana.sy/a", guid="g", published_at=utc_now()
        )
    )
    writer.commit()
    writer.close()
    assert db.scalar(select(func.count()).select_from(NewsArticle)) == 1
