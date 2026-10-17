"""POST /sync for the settings object: last write wins on ``updated_at``,
period keys always merge, and the usage streak merges by calendar day.

The streak rules, from ``_merge_streak`` in routers/sync.py (mirroring
``StreakMath.merge`` in the app):

* The streak with the later ``streak_last_date`` wins, whatever the
  settings stamp says.
* On the same day the longer streak wins (max of the counts).
* An earlier day, an invalid day or a missing count changes nothing.
* ``usage_started_at`` keeps the earliest valid value seen.
"""

import pytest

from conftest import at, bearer, parse_time, register, sync, system_execute


def _account(client, email):
    token = register(client, email)
    # Sign-up stamps the settings row with the server's clock. Move it back
    # before T0, as for an account made long ago, so pushes stamped around
    # T0 count as newer.
    system_execute(
        "UPDATE user_settings SET updated_at = '2000-01-01T00:00:00Z' "
        "WHERE user_id = (SELECT id FROM users WHERE email = :email)",
        email=email,
    )
    return token


@pytest.fixture
def alice(client):
    """Alice's token, with an old settings stamp."""
    return _account(client, "alice@example.com")


@pytest.fixture
def bob(client):
    """Bob's token, with an old settings stamp."""
    return _account(client, "bob@example.com")


def push(client, token, **settings):
    """Sync only settings; returns the settings the server answers with."""
    return sync(client, token, settings=settings)["settings"]


def test_settings_are_stored_and_returned(client, alice):
    # From the live script.
    stored = push(
        client,
        alice,
        notifications_muted=True,
        monthly_income_amount="800.00",
        processed_period_keys=["leftover:m:2026-01"],
        display_name="Sync Tester",
        gender="male",
        phone="+963 912345678",
        hidden_categories=["تعليم", "ترفيه", "تعليم"],
        dark_mode=True,
        updated_at=at(0),
    )
    assert stored["notifications_muted"] is True
    assert stored["notifications_enabled"] is False
    assert stored["monthly_income_amount"] == "800.00"
    assert stored["processed_period_keys"] == ["leftover:m:2026-01"]
    assert stored["display_name"] == "Sync Tester"
    assert stored["gender"] == "male"
    assert stored["phone"] == "+963 912345678"
    assert stored["hidden_categories"] == ["تعليم", "ترفيه"]
    assert stored["dark_mode"] is True
    assert stored["has_photo"] is False
    assert parse_time(stored["updated_at"]) == parse_time(at(0))


def test_settings_are_returned_on_every_sync(client, alice):
    push(client, alice, dark_mode=True, updated_at=at(0))
    first = sync(client, alice)
    later = sync(client, alice, last_sync_at=first["server_time"])
    assert later["settings"]["dark_mode"] is True


def test_profile_fields_go_to_the_account(client, alice):
    push(
        client,
        alice,
        display_name="  Alice  ",
        gender="female",
        birthdate="1990-01-01",
        country=" Syria ",
        city="Homs",
        street="  ",
        updated_at=at(0),
    )
    me = client.get("/auth/me", headers=bearer(alice)).json()
    assert (me["name"], me["gender"], me["birthdate"]) == ("Alice", "female", "1990-01-01")
    assert (me["country"], me["city"], me["street"]) == ("Syria", "Homs", None)
    cleared = push(client, alice, display_name=" ", updated_at=at(1))
    assert cleared["display_name"] is None


def test_rest_and_sync_agree_on_notification_flags(client, alice):
    push(client, alice, notify_low_balance=False, ai_data_enabled=True, updated_at=at(0))
    rest = client.get("/settings", headers=bearer(alice)).json()
    assert rest["notify_low_balance"] is False
    assert rest["ai_data_enabled"] is True


# Last write wins


def test_a_push_older_than_the_account_only_merges(client):
    # Without the backdating above: the row is stamped at sign-up, so
    # settings stamped before then are treated as stale. The app re-stamps
    # its settings when it signs in (ProfileSync.adoptAccount), so its first
    # push is newer.
    token = register(client, "carol@example.com")
    stale = push(client, token, dark_mode=True, processed_period_keys=["k"], updated_at=at(0))
    assert stale["dark_mode"] is None
    assert stale["processed_period_keys"] == ["k"]


def test_newer_settings_replace_older_ones(client, alice):
    push(client, alice, dark_mode=False, display_name="old", updated_at=at(0))
    newer = push(client, alice, dark_mode=True, display_name="new", updated_at=at(10))
    assert newer["dark_mode"] is True
    assert newer["display_name"] == "new"
    assert parse_time(newer["updated_at"]) == parse_time(at(10))


def test_older_settings_only_add_period_keys(client, alice):
    push(client, alice, dark_mode=True, display_name="kept", processed_period_keys=["b"], updated_at=at(10))
    stale = push(
        client,
        alice,
        dark_mode=False,
        display_name="stale",
        notifications_muted=True,
        processed_period_keys=["a", "b"],
        updated_at=at(5),
    )
    assert stale["dark_mode"] is True
    assert stale["display_name"] == "kept"
    assert stale["notifications_muted"] is False
    assert stale["processed_period_keys"] == ["a", "b"]


def test_a_stale_push_keeps_the_settings_stamp(client, alice):
    """A stale push that only merges keys must not move ``updated_at``.

    Otherwise the stamp jumps to the server's clock and a genuinely newer
    edit, made before that moment but pushed after it, is rejected as old.
    """
    push(client, alice, dark_mode=True, updated_at=at(10))
    merged = push(client, alice, processed_period_keys=["late-key"], updated_at=at(5))
    assert parse_time(merged["updated_at"]) == parse_time(at(10))
    newer = push(client, alice, dark_mode=False, updated_at=at(20))
    assert newer["dark_mode"] is False
    assert newer["processed_period_keys"] == ["late-key"]


def test_a_stale_streak_push_keeps_the_settings_stamp(client, alice):
    push(client, alice, display_name="first", updated_at=at(10))
    push(client, alice, streak_count=1, streak_last_date="2025-03-02", updated_at=at(5))
    newer = push(client, alice, display_name="second", updated_at=at(20))
    assert newer["display_name"] == "second"
    assert newer["streak_count"] == 1


def test_equal_stamps_apply_the_incoming_settings(client, alice):
    push(client, alice, dark_mode=False, updated_at=at(10))
    assert push(client, alice, dark_mode=True, updated_at=at(10))["dark_mode"] is True


def test_settings_without_a_stamp_are_applied(client, alice):
    push(client, alice, dark_mode=False, updated_at=at(10))
    assert push(client, alice, dark_mode=True)["dark_mode"] is True


def test_period_keys_are_a_sorted_union(client, alice):
    push(client, alice, processed_period_keys=["m:2025-02", "m:2025-01"], updated_at=at(0))
    merged = push(client, alice, processed_period_keys=["m:2025-03", "m:2025-01"], updated_at=at(1))
    assert merged["processed_period_keys"] == ["m:2025-01", "m:2025-02", "m:2025-03"]


def test_no_settings_in_the_push_changes_nothing(client, alice):
    push(client, alice, dark_mode=True, updated_at=at(0))
    body = sync(client, alice, settings=None)
    assert body["settings"]["dark_mode"] is True


# Income and currencies


def test_null_income_clears_it_but_a_missing_one_is_kept(client, alice):
    push(client, alice, monthly_income_amount="500", weekly_income_amount="100", updated_at=at(0))
    kept = push(client, alice, dark_mode=True, updated_at=at(1))
    assert (kept["monthly_income_amount"], kept["weekly_income_amount"]) == ("500.00", "100.00")
    cleared = push(client, alice, monthly_income_amount=None, updated_at=at(2))
    assert cleared["monthly_income_amount"] is None
    assert cleared["weekly_income_amount"] == "100.00"


def test_enabled_currencies_are_normalized(client, alice):
    stored = push(client, alice, enabled_currencies=["usd", "EUR", "usd", "bad!", ""], updated_at=at(0))
    assert stored["enabled_currencies"] == ["SYP", "USD", "EUR"]


def test_active_currency_must_be_enabled(client, alice):
    push(client, alice, enabled_currencies=["USD"], active_currency="usd", updated_at=at(0))
    assert push(client, alice, updated_at=at(1))["active_currency"] == "USD"
    assert push(client, alice, active_currency="EUR", updated_at=at(2))["active_currency"] == "SYP"


def test_income_overrides_are_normalized(client, alice):
    stored = push(
        client,
        alice,
        income_overrides_by_currency={
            "usd": {"monthly": "100", "weekly": "-5"},
            "SYP": {"monthly": "999"},
            "EUR": {"monthly": "abc"},
            "GBP": "not a dict",
            "TRY": {"weekly": 25.5},
        },
        updated_at=at(0),
    )
    assert stored["income_overrides_by_currency"] == {
        "USD": {"monthly": "100.00"},
        "TRY": {"weekly": "25.50"},
    }


def test_hidden_categories_are_trimmed_capped_and_unique(client, alice):
    labels = [f"  label {n}  " for n in range(60)] + ["x" * 50]
    stored = push(client, alice, hidden_categories=labels, updated_at=at(0))
    assert len(stored["hidden_categories"]) == 50
    assert stored["hidden_categories"][0] == "label 0"
    short = push(client, alice, hidden_categories=["x" * 50, "", "a"], updated_at=at(1))
    assert short["hidden_categories"] == ["x" * 40, "a"]


@pytest.mark.parametrize(
    "settings",
    [
        {"monthly_income_amount": "1e20"},
        {"display_name": "n" * 101},
        {"streak_last_date": "2025-03-011"},
        {"processed_period_keys": ["k" * 101]},
        {"dark_mode": "sometimes"},
    ],
)
def test_invalid_settings_are_refused(client, alice, settings):
    response = client.post("/sync", json={"settings": settings}, headers=bearer(alice))
    assert response.status_code == 422


# Usage streak


def test_streak_with_the_later_day_wins_even_from_older_settings(client, alice):
    push(client, alice, streak_count=5, streak_last_date="2025-03-01", updated_at=at(10))
    merged = push(client, alice, streak_count=1, streak_last_date="2025-03-03", updated_at=at(0))
    assert (merged["streak_count"], merged["streak_last_date"]) == (1, "2025-03-03")


def test_streak_on_the_same_day_keeps_the_longer_count(client, alice):
    push(client, alice, streak_count=3, streak_last_date="2025-03-01", updated_at=at(0))
    shorter = push(client, alice, streak_count=2, streak_last_date="2025-03-01", updated_at=at(1))
    assert shorter["streak_count"] == 3
    longer = push(client, alice, streak_count=7, streak_last_date="2025-03-01", updated_at=at(2))
    assert longer["streak_count"] == 7


def test_streak_with_an_earlier_day_is_ignored(client, alice):
    push(client, alice, streak_count=2, streak_last_date="2025-03-05", updated_at=at(0))
    merged = push(client, alice, streak_count=40, streak_last_date="2025-03-04", updated_at=at(10))
    assert (merged["streak_count"], merged["streak_last_date"]) == (2, "2025-03-05")


@pytest.mark.parametrize(
    "fields",
    [
        {"streak_count": 9, "streak_last_date": "03/09/2025"},
        {"streak_count": 9, "streak_last_date": ""},
        {"streak_count": None, "streak_last_date": "2025-03-09"},
    ],
)
def test_streak_needs_a_count_and_a_valid_day(client, alice, fields):
    push(client, alice, streak_count=2, streak_last_date="2025-03-05", updated_at=at(0))
    merged = push(client, alice, **fields, updated_at=at(1))
    assert (merged["streak_count"], merged["streak_last_date"]) == (2, "2025-03-05")


def test_first_streak_is_taken_and_negative_counts_become_zero(client, alice):
    assert push(client, alice, updated_at=at(0))["streak_count"] is None
    merged = push(client, alice, streak_count=-4, streak_last_date="2025-03-01", updated_at=at(1))
    assert (merged["streak_count"], merged["streak_last_date"]) == (0, "2025-03-01")


def test_usage_start_keeps_the_earliest_valid_value(client, alice):
    first = push(client, alice, usage_started_at="2025-02-01T00:00:00Z", updated_at=at(0))
    assert first["usage_started_at"] == "2025-02-01T00:00:00Z"
    later = push(client, alice, usage_started_at="2025-02-10T00:00:00Z", updated_at=at(1))
    assert later["usage_started_at"] == "2025-02-01T00:00:00Z"
    junk = push(client, alice, usage_started_at="yesterday", updated_at=at(2))
    assert junk["usage_started_at"] == "2025-02-01T00:00:00Z"
    # Older settings still move the start earlier.
    earlier = push(client, alice, usage_started_at="2025-01-15T00:00:00+00:00", updated_at=at(-100))
    assert earlier["usage_started_at"] == "2025-01-15T00:00:00+00:00"


def test_an_unreadable_usage_start_is_replaced(client, alice):
    push(client, alice, usage_started_at="garbage", updated_at=at(0))
    fixed = push(client, alice, usage_started_at="2025-02-01T00:00:00Z", updated_at=at(1))
    assert fixed["usage_started_at"] == "2025-02-01T00:00:00Z"


# Accounts


def test_settings_are_per_account(client, alice, bob):
    push(
        client,
        alice,
        dark_mode=True,
        streak_count=9,
        streak_last_date="2025-03-09",
        processed_period_keys=["a"],
        updated_at=at(0),
    )
    other = push(client, bob, updated_at=at(0))
    assert other["dark_mode"] is None
    assert other["streak_count"] is None
    assert other["processed_period_keys"] == []
    assert sync(client, alice)["settings"]["streak_count"] == 9
