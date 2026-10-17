"""Shared fixtures and helpers for the backend tests.

Tests run against a real, throwaway Postgres: row security needs one.

    TEST_DATABASE_URL=postgresql://user:pass@localhost:5432/waffer_test \
        python -m pytest backend/tests

The role in that URL must not be a superuser or have BYPASSRLS, or the row
security tests fail (see backend/README.md for the setup). Every table in
that database is emptied between tests. Without the variable the tests are
skipped.

Nothing here reaches the network: password reset emails and news feeds are
replaced with fakes, and Python sockets refuse to connect.
"""

import os
import socket
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

BACKEND = Path(__file__).resolve().parents[1]
TEST_DATABASE_URL = os.getenv("TEST_DATABASE_URL")

if TEST_DATABASE_URL:
    os.environ["DATABASE_URL"] = TEST_DATABASE_URL
    os.environ.setdefault("SECRET_KEY", "test-secret-" + "x" * 40)
    os.environ.pop("ENABLE_API_DOCS", None)
    os.environ.pop("CORS_ORIGINS", None)
    os.environ["TRUST_PROXY_HEADERS"] = "0"
    for name in ("SMTP_HOST", "SMTP_USERNAME", "SMTP_PASSWORD", "SMTP_FROM"):
        os.environ[name] = "test"
    sys.path.insert(0, str(BACKEND))

# Every collection POST /sync accepts, in the order the request lists them.
SYNC_COLLECTIONS = (
    "transactions",
    "savings_goals",
    "savings_transfers",
    "shopping_lists",
    "shopping_items",
    "recurring_expenses",
    "notifications",
    "expense_categories",
    "expense_presets",
)

# A fixed base time for client stamps, so tests never depend on the clock.
T0 = datetime(2025, 3, 1, 12, 0, tzinfo=timezone.utc)


def pytest_collection_modifyitems(config, items):
    """Skip every test when TEST_DATABASE_URL is not set."""
    if TEST_DATABASE_URL:
        return
    skip = pytest.mark.skip(reason="TEST_DATABASE_URL is not set")
    for item in items:
        item.add_marker(skip)


@pytest.fixture(scope="session")
def main_module():
    """The app module, imported once (it creates the tables)."""
    import main

    return main


@pytest.fixture(autouse=True)
def clean_state(request):
    """Empty every table and the rate limiter before each test."""
    if not TEST_DATABASE_URL:
        yield
        return
    from sqlalchemy import text

    import main  # noqa: F401  (creates the tables and policies)
    from database import Base, engine
    from rate_limit import limiter

    tables = ", ".join(Base.metadata.tables)
    with engine.begin() as connection:
        connection.execute(text(f"TRUNCATE {tables} RESTART IDENTITY CASCADE"))
    limiter.clear()
    yield


@pytest.fixture(autouse=True)
def no_network(monkeypatch):
    """Fail loudly if anything in Python tries to open a network socket.

    Postgres is reached through libpq, which does not use Python sockets, and
    TestClient calls the app in-process.
    """

    def refuse(*_args, **_kwargs):
        raise RuntimeError("network access is disabled in the tests")

    monkeypatch.setattr(socket.socket, "connect", refuse)
    monkeypatch.setattr(socket.socket, "connect_ex", refuse)
    monkeypatch.setattr(socket, "getaddrinfo", refuse)
    monkeypatch.setattr(socket, "create_connection", refuse)


@pytest.fixture(autouse=True)
def offline_services(monkeypatch):
    """Default fakes: email sending fails and every news feed is down.

    Tests that need them working use ``sent_codes`` or ``news_feeds``.
    """
    if not TEST_DATABASE_URL:
        return
    import news_service
    import password_reset

    def no_email(_to, _code):
        raise password_reset.EmailSendFailed()

    def no_feed(_source):
        raise news_service.NewsFeedUnavailable()

    monkeypatch.setattr(password_reset, "send_code", no_email)
    monkeypatch.setattr(news_service, "fetch_feed", no_feed)


@pytest.fixture
def client(main_module):
    """A TestClient for the app."""
    from fastapi.testclient import TestClient

    # No "with": the lifespan would start the hourly news fetch.
    return TestClient(main_module.app)


@pytest.fixture
def sent_codes(monkeypatch):
    """Reset emails, captured instead of sent."""
    import password_reset

    sent: dict[str, str] = {}
    monkeypatch.setattr(password_reset, "send_code", lambda to, code: sent.__setitem__(to, code))
    return sent


@pytest.fixture
def alice(client):
    """A signed-in user's bearer token."""
    return register(client, "alice@example.com")


@pytest.fixture
def bob(client):
    """A second, unrelated user's bearer token."""
    return register(client, "bob@example.com")


def register(client, email, password="correct horse 1", **extra):
    """Sign up [email] and return its bearer token."""
    response = client.post(
        "/auth/register",
        json={"email": email, "password": password, **extra},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def bearer(token: str) -> dict:
    """Authorization header for [token]."""
    return {"Authorization": f"Bearer {token}"}


def at(minutes: float = 0) -> str:
    """ISO stamp [minutes] after T0, as the app sends it."""
    return (T0 + timedelta(minutes=minutes)).isoformat()


def parse_time(value: str) -> datetime:
    """Parse a timestamp from a response ("Z" or an offset)."""
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def sync_payload(last_sync_at=None, settings=None, deletes=None, **upserts) -> dict:
    """A POST /sync body. ``upserts`` and ``deletes`` are keyed by collection."""
    deletes = deletes or {}
    body = {"last_sync_at": last_sync_at, "settings": settings}
    for name in SYNC_COLLECTIONS:
        body[name] = {
            "upserts": upserts.get(name, []),
            "deletes": deletes.get(name, []),
        }
    return body


def sync(client, token, **kwargs) -> dict:
    """POST /sync and return the body, asserting a 200."""
    response = client.post("/sync", json=sync_payload(**kwargs), headers=bearer(token))
    assert response.status_code == 200, response.text
    return response.json()


def ids(collection: dict) -> list[str]:
    """Client ids of a response collection's upserts."""
    return [row["client_id"] for row in collection["upserts"]]


def deleted_ids(collection: dict) -> list[str]:
    """Client ids of a response collection's tombstones."""
    return [row["client_id"] for row in collection["deletes"]]


def system_scalar(sql: str, **params):
    """Run one query as the server, past row security."""
    from sqlalchemy import text

    from database import SessionLocal
    from row_security import bind_system

    session = SessionLocal()
    bind_system(session)
    try:
        return session.scalar(text(sql), params)
    finally:
        session.close()


def system_execute(sql: str, **params) -> None:
    """Run and commit one statement as the server, past row security."""
    from sqlalchemy import text

    from database import SessionLocal
    from row_security import bind_system

    session = SessionLocal()
    bind_system(session)
    try:
        session.execute(text(sql), params)
        session.commit()
    finally:
        session.close()
