"""POST /sync for the row collections: push, pull, tombstones and conflicts.

The rules, from routers/sync.py:

* Rows are matched by (user, client_id). A push creates or updates them.
* Last write wins on the client's ``updated_at`` (or its fallback field).
  An incoming row whose stamp is older than the stored one is ignored; an
  equal stamp is applied.
* A tombstone soft-deletes the row unless the row is newer than it. A later
  upsert newer than the tombstone brings the row back; an older one does not.
* The reply carries every row changed since ``last_sync_at``, compared with
  the stored (client) ``updated_at`` and ``deleted_at``; without it, every row.

Settings sync is in test_sync_settings.py. Every scenario of the old live
script (backend/_test_sync.py, now removed) is folded in here or in
test_sync_settings.py and marked "From the live script".
"""

import pytest

from conftest import (
    SYNC_COLLECTIONS,
    at,
    bearer,
    deleted_ids,
    ids,
    parse_time,
    register,
    sync,
    sync_payload,
    system_scalar,
)

# One valid row per collection, stamped at T0 unless overridden.


def transaction(client_id="tx-1", stamp=0, **extra):
    """A transaction row as the app pushes it."""
    return {
        "client_id": client_id,
        "type": "expense",
        "amount": "12.50",
        "category": "طعام",
        "payment_method": "نقد",
        "note": "offline expense",
        "occurred_at": at(stamp),
        "updated_at": at(stamp),
        **extra,
    }


def goal(client_id="g-1", stamp=0, **extra):
    """A savings goal row."""
    return {
        "client_id": client_id,
        "name": "هدف تجريبي",
        "target_amount": "100.00",
        "duration": "month",
        "created_at": at(stamp),
        "updated_at": at(stamp),
        **extra,
    }


def transfer(client_id="sv-1", stamp=0, **extra):
    """A savings transfer into goal g-1."""
    return {
        "client_id": client_id,
        "goal_client_id": "g-1",
        "amount": "20.00",
        "kind": "manual",
        "direction": "to_savings",
        "occurred_at": at(stamp),
        "updated_at": at(stamp),
        **extra,
    }


def shopping_list(client_id="shopping_default", stamp=0, **extra):
    """The default shopping list."""
    return {"client_id": client_id, "name": "المشتريات", "updated_at": at(stamp), **extra}


def shopping_item(client_id="sh-1", stamp=0, **extra):
    """An item on the default shopping list."""
    return {
        "client_id": client_id,
        "list_client_id": "shopping_default",
        "name": "حليب",
        "created_at": at(stamp),
        "updated_at": at(stamp),
        **extra,
    }


def recurring(client_id="r-1", stamp=0, **extra):
    """A monthly recurring expense."""
    return {
        "client_id": client_id,
        "amount": "9.00",
        "category": "فواتير",
        "payment_method": "بطاقة",
        "unit": "month",
        "interval_count": 1,
        "next_due_at": at(stamp),
        "enabled": True,
        "requires_confirmation": True,
        "remind_on_income": True,
        "created_at": at(stamp),
        "updated_at": at(stamp),
        **extra,
    }


def notification(client_id="n-1", stamp=0, **extra):
    """A goal-reached notification."""
    return {
        "client_id": client_id,
        "type": "goalReached",
        "title": "تم الهدف",
        "message": "وصلت",
        "event_key": "goalReached:g-1",
        "related_id": "g-1",
        "metadata": {"goal": "g-1"},
        "created_at": at(stamp),
        "updated_at": at(stamp),
        **extra,
    }


def category(client_id="cat-1", stamp=0, **extra):
    """A custom expense category."""
    return {"client_id": client_id, "label": "قهوة", "icon_index": 2, "updated_at": at(stamp), **extra}


def preset(client_id="p-1", stamp=0, **extra):
    """An expense preset."""
    return {
        "client_id": client_id,
        "amount": "1500",
        "multiplier": 2,
        "currency_code": "SYP",
        "category": "طعام",
        "payment_method": "نقداً",
        "note": "خبز",
        "unit": "month",
        "interval_count": 1,
        "created_at": at(stamp),
        "updated_at": at(stamp),
        **extra,
    }


BUILDERS = {
    "transactions": transaction,
    "savings_goals": goal,
    "savings_transfers": transfer,
    "shopping_lists": shopping_list,
    "shopping_items": shopping_item,
    "recurring_expenses": recurring,
    "notifications": notification,
    "expense_categories": category,
    "expense_presets": preset,
}
# The field each test changes to tell two versions of a row apart.
CHANGE = {
    "transactions": ("amount", "18.00"),
    "savings_goals": ("target_amount", "250.00"),
    "savings_transfers": ("amount", "35.00"),
    "shopping_lists": ("name", "renamed"),
    "shopping_items": ("quantity", 4),
    "recurring_expenses": ("amount", "11.00"),
    "notifications": ("is_read", True),
    "expense_categories": ("icon_index", 7),
    "expense_presets": ("amount", "2500.00"),
}


def one_of_each(stamp=0) -> dict:
    """Upserts for every collection, linked to each other the way the app links them."""
    return {name: [build(stamp=stamp)] for name, build in BUILDERS.items()}


def row(collection: dict, client_id: str) -> dict:
    """The upsert with [client_id] from a response collection."""
    return next(item for item in collection["upserts"] if item["client_id"] == client_id)


# Auth


def test_sync_needs_a_valid_token(client):
    # From the live script.
    assert client.post("/sync", json=sync_payload()).status_code == 401
    assert client.post("/sync", json=sync_payload(), headers=bearer("not-a-real-token")).status_code == 401


# Push


def test_first_sync_uploads_every_collection(client, alice):
    # From the live script: an offline device's first sync.
    body = sync(client, alice, **one_of_each())

    for name, build in BUILDERS.items():
        assert ids(body[name]) == [build()["client_id"]], name
        assert body[name]["deletes"] == [], name

    tx = row(body["transactions"], "tx-1")
    assert (tx["amount"], tx["category"], tx["payment_method"], tx["note"]) == (
        "12.50", "طعام", "نقد", "offline expense",
    )
    assert parse_time(tx["updated_at"]) == parse_time(at(0))
    assert tx["currency_code"] == "SYP"

    rec = row(body["recurring_expenses"], "r-1")
    assert rec["requires_confirmation"] is True
    assert rec["remind_on_income"] is True
    assert rec["remind_at"] is None
    assert rec["unit"] == "month"

    saved = row(body["savings_transfers"], "sv-1")
    assert saved["goal_client_id"] == "g-1"
    assert saved["direction"] == "to_savings"

    item = row(body["shopping_items"], "sh-1")
    assert item["list_client_id"] == "shopping_default"
    assert item["quantity"] == 1

    note = row(body["notifications"], "n-1")
    assert note["metadata"] == {"goal": "g-1"}
    assert note["is_read"] is False

    assert row(body["expense_categories"], "cat-1")["icon_index"] == 2
    kept = row(body["expense_presets"], "p-1")
    assert (kept["multiplier"], kept["note"], kept["amount"]) == (2, "خبز", "1500.00")

    # The REST routes see the same rows.
    assert len(client.get("/transactions", headers=bearer(alice)).json()) == 1
    assert client.get("/savings-goals", headers=bearer(alice)).json()[0]["saved_amount"] == "20.00"


def test_repeating_a_push_does_not_duplicate_rows(client, alice):
    # From the live script.
    first = sync(client, alice, **one_of_each())
    sync(client, alice, last_sync_at=first["server_time"], **one_of_each())
    for name in SYNC_COLLECTIONS:
        table = {"shopping_items": "shopping_items"}.get(name, name)
        assert system_scalar(f"SELECT count(*) FROM {table}") == 1, name
    assert len(client.get("/transactions", headers=bearer(alice)).json()) == 1


def test_rows_without_updated_at_use_their_own_event_time(client, alice):
    pushed = transaction(updated_at=None, occurred_at=at(5))
    body = sync(client, alice, transactions=[pushed])
    assert parse_time(row(body["transactions"], "tx-1")["updated_at"]) == parse_time(at(5))


def test_occurred_at_is_kept_from_the_client(client, alice):
    body = sync(client, alice, transactions=[transaction(occurred_at="2025-01-01T08:00:00+03:00")])
    assert parse_time(row(body["transactions"], "tx-1")["occurred_at"]) == parse_time(
        "2025-01-01T05:00:00+00:00"
    )


def test_item_for_an_unknown_list_creates_the_list(client, alice):
    body = sync(client, alice, shopping_items=[shopping_item(list_client_id="new-list")])
    assert ids(body["shopping_lists"]) == ["new-list"]
    assert row(body["shopping_lists"], "new-list")["name"] == "المشتريات"
    assert row(body["shopping_items"], "sh-1")["list_client_id"] == "new-list"


def test_transfer_for_an_unknown_goal_is_kept_without_a_goal(client, alice):
    body = sync(client, alice, savings_transfers=[transfer(goal_client_id="missing")])
    assert row(body["savings_transfers"], "sv-1")["goal_client_id"] is None


def test_transfer_direction_comes_from_kind(client, alice):
    body = sync(client, alice, savings_transfers=[transfer(direction=None, kind="withdraw", goal_client_id=None)])
    assert row(body["savings_transfers"], "sv-1")["direction"] == "to_balance"


def test_notification_with_a_known_event_key_updates_that_notification(client, alice):
    sync(client, alice, notifications=[notification(client_id="n-1")])
    body = sync(client, alice, notifications=[notification(client_id="n-2", stamp=5, is_read=True)])
    assert ids(body["notifications"]) == ["n-1"]
    assert row(body["notifications"], "n-1")["is_read"] is True
    assert system_scalar("SELECT count(*) FROM notifications") == 1


def test_rest_rows_show_up_in_sync(client, alice):
    client.post(
        "/transactions",
        json={"client_id": "rest-1", "type": "income", "amount": "3"},
        headers=bearer(alice),
    )
    assert ids(sync(client, alice)["transactions"]) == ["rest-1"]


@pytest.mark.parametrize(
    "collection, bad",
    [
        ("transactions", {"type": "gift"}),
        ("transactions", {"amount": "0"}),
        ("savings_goals", {"duration": "decade"}),
        ("savings_transfers", {"kind": "gift"}),
        ("shopping_lists", {"name": ""}),
        ("shopping_items", {"name": ""}),
        ("recurring_expenses", {"amount": None}),
        ("notifications", {"metadata": {"n": 1}}),
        ("expense_categories", {"label": ""}),
        ("expense_presets", {"multiplier": 11}),
        ("expense_presets", {"unit": "year"}),
    ],
)
def test_an_invalid_row_rejects_the_whole_push(client, alice, collection, bad):
    rows = one_of_each()
    rows[collection] = [{**rows[collection][0], **bad}]
    response = client.post("/sync", json=sync_payload(**rows), headers=bearer(alice))
    assert response.status_code == 422
    # Nothing from the batch was stored.
    assert system_scalar("SELECT count(*) FROM transactions") == 0


def test_an_unknown_recurrence_unit_is_refused(client, alice):
    response = client.post(
        "/sync", json=sync_payload(recurring_expenses=[recurring(unit="year")]), headers=bearer(alice)
    )
    assert response.status_code == 422
    assert response.json()["detail"] == "Invalid recurrence unit"


def test_a_transfer_without_direction_or_kind_is_refused(client, alice):
    response = client.post(
        "/sync",
        json=sync_payload(savings_transfers=[transfer(direction=None, kind=None)]),
        headers=bearer(alice),
    )
    assert response.status_code == 422


# Pull


def test_pull_without_last_sync_returns_everything(client, alice):
    sync(client, alice, transactions=[transaction("a", stamp=0), transaction("b", stamp=60)])
    assert sorted(ids(sync(client, alice)["transactions"])) == ["a", "b"]


@pytest.mark.parametrize("collection", SYNC_COLLECTIONS)
def test_pull_returns_only_rows_changed_after_last_sync(client, alice, collection):
    build = BUILDERS[collection]
    rows = [build(client_id="old", stamp=0), build(client_id="new", stamp=60)]
    if collection == "notifications":
        rows[1]["event_key"] = "other-event"
    sync(client, alice, **{collection: rows})

    body = sync(client, alice, last_sync_at=at(30))
    assert ids(body[collection]) == ["new"]


def test_pull_with_no_changes_is_empty(client, alice):
    # From the live script: an incremental sync after the last one.
    first = sync(client, alice, **one_of_each())
    again = sync(client, alice, last_sync_at=first["server_time"])
    for name in SYNC_COLLECTIONS:
        assert again[name] == {"upserts": [], "deletes": []}, name


def test_last_sync_is_exclusive(client, alice):
    sync(client, alice, transactions=[transaction(stamp=10)])
    assert ids(sync(client, alice, last_sync_at=at(10))["transactions"]) == []
    assert ids(sync(client, alice, last_sync_at=at(9))["transactions"]) == ["tx-1"]


def test_a_second_device_pulls_what_the_first_pushed(client, alice):
    device_b = client.post(
        "/auth/login", json={"email": "alice@example.com", "password": "correct horse 1"}
    ).json()["access_token"]
    sync(client, alice, transactions=[transaction(stamp=60)])
    pulled = sync(client, device_b, last_sync_at=at(30))
    assert ids(pulled["transactions"]) == ["tx-1"]


def test_server_time_is_the_servers_clock(client, alice):
    from datetime import datetime, timedelta, timezone

    body = sync(client, alice)
    assert abs(parse_time(body["server_time"]) - datetime.now(timezone.utc)) < timedelta(minutes=1)


# Conflicts (last write wins)


@pytest.mark.parametrize("collection", SYNC_COLLECTIONS)
def test_newer_push_wins_older_push_loses(client, alice, collection):
    build = BUILDERS[collection]
    field, value = CHANGE[collection]
    sync(client, alice, **{collection: [build(stamp=10)]})

    newer = sync(client, alice, **{collection: [build(stamp=20, **{field: value})]})
    assert row(newer[collection], build()["client_id"])[field] == value

    # An older version arriving late is ignored.
    original = build()[field] if field in build() else None
    stale = {field: original if original is not None else 1}
    if collection == "notifications":
        stale = {field: False}
    sync(client, alice, **{collection: [build(stamp=15, **stale)]})
    current = sync(client, alice)
    assert row(current[collection], build()["client_id"])[field] == value
    assert parse_time(row(current[collection], build()["client_id"])["updated_at"]) == parse_time(at(20))


def test_equal_stamps_apply_the_incoming_row(client, alice):
    sync(client, alice, transactions=[transaction(stamp=10)])
    body = sync(client, alice, transactions=[transaction(stamp=10, amount="99")])
    assert row(body["transactions"], "tx-1")["amount"] == "99.00"


def test_live_script_update_and_conflict(client, alice):
    # From the live script: update with a later stamp, then an older conflict.
    sync(client, alice, transactions=[transaction(stamp=0)])
    updated = sync(client, alice, transactions=[transaction(stamp=5, amount="18.00", note="updated")])
    assert row(updated["transactions"], "tx-1")["amount"] == "18.00"
    sync(client, alice, transactions=[transaction(stamp=-30, amount="1.00", category="قديم")])
    listed = client.get("/transactions", headers=bearer(alice)).json()
    assert [(r["amount"], r["note"]) for r in listed] == [("18.00", "updated")]


# Tombstones


@pytest.mark.parametrize("collection", SYNC_COLLECTIONS)
def test_deletes_reach_other_devices(client, alice, collection):
    build = BUILDERS[collection]
    client_id = build()["client_id"]
    sync(client, alice, **one_of_each(stamp=0))

    pushed = sync(
        client,
        alice,
        last_sync_at=at(5),
        deletes={collection: [{"client_id": client_id, "deleted_at": at(10)}]},
    )
    assert deleted_ids(pushed[collection]) == [client_id]

    # Another device that last synced before the delete hears of it...
    pulled = sync(client, alice, last_sync_at=at(5))
    assert deleted_ids(pulled[collection]) == [client_id]
    assert ids(pulled[collection]) == []
    assert parse_time(pulled[collection]["deletes"][0]["deleted_at"]) == parse_time(at(10))
    # ...and one that synced after it does not hear it again.
    assert sync(client, alice, last_sync_at=at(10))[collection]["deletes"] == []
    # A full pull still lists it as deleted, not live.
    full = sync(client, alice)
    assert client_id in deleted_ids(full[collection])
    assert client_id not in ids(full[collection])


@pytest.mark.parametrize("collection", SYNC_COLLECTIONS)
def test_a_stale_upsert_does_not_resurrect_a_deleted_row(client, alice, collection):
    build = BUILDERS[collection]
    client_id = build()["client_id"]
    sync(client, alice, **{collection: [build(stamp=0)]})
    sync(client, alice, deletes={collection: [{"client_id": client_id, "deleted_at": at(10)}]})

    # A device that edited the row before the delete pushes its edit late.
    sync(client, alice, **{collection: [build(stamp=5)]})
    full = sync(client, alice)
    assert client_id not in ids(full[collection])
    assert client_id in deleted_ids(full[collection])


def test_an_upsert_newer_than_the_delete_brings_the_row_back(client, alice):
    sync(client, alice, transactions=[transaction(stamp=0)])
    sync(client, alice, deletes={"transactions": [{"client_id": "tx-1", "deleted_at": at(10)}]})
    body = sync(client, alice, transactions=[transaction(stamp=20, amount="5")])
    assert row(body["transactions"], "tx-1")["amount"] == "5.00"
    assert deleted_ids(body["transactions"]) == []


def test_a_delete_older_than_the_row_is_ignored(client, alice):
    sync(client, alice, transactions=[transaction(stamp=20)])
    sync(client, alice, deletes={"transactions": [{"client_id": "tx-1", "deleted_at": at(10)}]})
    full = sync(client, alice)
    assert ids(full["transactions"]) == ["tx-1"]
    assert deleted_ids(full["transactions"]) == []


def test_a_later_tombstone_does_not_move_an_earlier_delete_back(client, alice):
    sync(client, alice, transactions=[transaction(stamp=0)])
    sync(client, alice, deletes={"transactions": [{"client_id": "tx-1", "deleted_at": at(10)}]})
    sync(client, alice, deletes={"transactions": [{"client_id": "tx-1", "deleted_at": at(5)}]})
    stamp = sync(client, alice)["transactions"]["deletes"][0]["deleted_at"]
    assert parse_time(stamp) == parse_time(at(10))


def test_a_tombstone_for_an_unknown_row_is_ignored(client, alice):
    body = sync(client, alice, deletes={"transactions": [{"client_id": "never-seen"}]})
    assert body["transactions"] == {"upserts": [], "deletes": []}


def test_a_tombstone_without_a_stamp_uses_the_server_clock(client, alice):
    sync(client, alice, transactions=[transaction(stamp=0)])
    body = sync(client, alice, deletes={"transactions": [{"client_id": "tx-1"}]})
    assert parse_time(body["transactions"]["deletes"][0]["deleted_at"]) > parse_time(at(0))


def test_upsert_and_delete_in_one_push_ends_deleted(client, alice):
    # Upserts are applied first, then deletes.
    body = sync(
        client,
        alice,
        transactions=[transaction(stamp=10)],
        deletes={"transactions": [{"client_id": "tx-1", "deleted_at": at(10)}]},
    )
    assert deleted_ids(body["transactions"]) == ["tx-1"]


def test_deleted_rows_lose_their_private_text(client, alice):
    sync(client, alice, **one_of_each())
    sync(
        client,
        alice,
        deletes={
            "transactions": [{"client_id": "tx-1", "deleted_at": at(10)}],
            "notifications": [{"client_id": "n-1", "deleted_at": at(10)}],
        },
    )
    assert system_scalar("SELECT note || category || payment_method FROM transactions") == ""
    assert system_scalar("SELECT title || message FROM notifications") == ""
    assert system_scalar("SELECT event_metadata::text FROM notifications") == "{}"


def test_live_script_delete_flow(client, alice):
    # From the live script: deletes are returned and hidden from REST. Like
    # the script, the tombstones carry real clock stamps just after the
    # cursor, so the reply echoes them (see the known gap at the end).
    from datetime import datetime, timedelta, timezone

    def soon(seconds):
        return (datetime.now(timezone.utc) + timedelta(seconds=seconds)).isoformat()

    first = sync(client, alice, transactions=[transaction(stamp=0)], expense_presets=[preset(stamp=0)])
    deleted = sync(
        client,
        alice,
        last_sync_at=first["server_time"],
        deletes={"transactions": [{"client_id": "tx-1", "deleted_at": soon(10)}]},
    )
    assert deleted_ids(deleted["transactions"]) == ["tx-1"]
    assert client.get("/transactions", headers=bearer(alice)).json() == []
    preset_gone = sync(
        client,
        alice,
        last_sync_at=deleted["server_time"],
        deletes={"expense_presets": [{"client_id": "p-1", "deleted_at": soon(20)}]},
    )
    assert deleted_ids(preset_gone["expense_presets"]) == ["p-1"]


def test_deleting_a_goal_keeps_its_transfers_linked(client, alice):
    sync(client, alice, savings_goals=[goal()], savings_transfers=[transfer()])
    body = sync(client, alice, deletes={"savings_goals": [{"client_id": "g-1", "deleted_at": at(10)}]})
    assert row(body["savings_transfers"], "sv-1")["goal_client_id"] == "g-1"


# Accounts


def test_a_second_user_sees_none_of_the_first_users_rows(client, alice, bob):
    # From the live script.
    sync(client, alice, **one_of_each())
    other = sync(client, bob)
    for name in SYNC_COLLECTIONS:
        assert other[name] == {"upserts": [], "deletes": []}, name


def test_same_client_ids_in_two_accounts_stay_separate(client, alice, bob):
    sync(client, alice, **one_of_each())
    bob_body = sync(client, bob, transactions=[transaction(amount="1", stamp=60)])
    assert [r["amount"] for r in bob_body["transactions"]["upserts"]] == ["1.00"]
    alice_body = sync(client, alice)
    assert [r["amount"] for r in alice_body["transactions"]["upserts"]] == ["12.50"]


def test_tombstones_cannot_delete_another_users_rows(client, alice, bob):
    sync(client, alice, **one_of_each())
    sync(
        client,
        bob,
        deletes={name: [{"client_id": build()["client_id"], "deleted_at": at(99)}] for name, build in BUILDERS.items()},
    )
    full = sync(client, alice)
    for name, build in BUILDERS.items():
        assert ids(full[name]) == [build()["client_id"]], name
        assert full[name]["deletes"] == [], name


def test_links_resolve_inside_the_pushing_account_only(client, alice, bob):
    sync(client, alice, savings_goals=[goal()], shopping_lists=[shopping_list(client_id="l-a")])
    # Bob names Alice's goal and list; he gets no goal and a list of his own.
    body = sync(
        client,
        bob,
        savings_transfers=[transfer()],
        shopping_items=[shopping_item(list_client_id="l-a")],
    )
    assert row(body["savings_transfers"], "sv-1")["goal_client_id"] is None
    assert ids(body["shopping_lists"]) == ["l-a"]
    assert system_scalar("SELECT count(*) FROM shopping_lists") == 2
    alice_goal = client.get("/savings-goals", headers=bearer(alice)).json()[0]
    assert alice_goal["saved_amount"] == "0.00"


def test_a_signed_out_token_cannot_sync(client):
    token = register(client, "carol@example.com", password="first password")
    client.post(
        "/auth/password/change",
        json={"current_password": "first password", "new_password": "second password"},
        headers=bearer(token),
    )
    assert client.post("/sync", json=sync_payload(), headers=bearer(token)).status_code == 401


# Known gap: the pull cursor compares the server's clock with client stamps.


@pytest.mark.xfail(
    strict=True,
    reason=(
        "Known gap: pull filters on the client's updated_at, so a row edited "
        "offline before another device's last sync, but pushed after it, is "
        "never pulled by that device. Needs a server-side change stamp."
    ),
)
def test_a_late_push_of_an_old_edit_reaches_a_device_that_synced_in_between(client, alice):
    device_b = client.post(
        "/auth/login", json={"email": "alice@example.com", "password": "correct horse 1"}
    ).json()["access_token"]
    # Device B syncs; its cursor is the server's time now.
    cursor = sync(client, device_b)["server_time"]
    # Device A pushes an edit it made offline at T0, long before that.
    sync(client, alice, transactions=[transaction(stamp=0)])
    # Device B pulls from its cursor and should see the new row.
    assert ids(sync(client, device_b, last_sync_at=cursor)["transactions"]) == ["tx-1"]
