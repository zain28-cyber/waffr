"""/notifications: in-app notifications, one per event key, with read state
and soft deletes.
"""

import pytest

from conftest import bearer, deleted_ids, sync


def _create(client, token, **body):
    data = {
        "type": "goalReached",
        "title": "Goal reached",
        "message": "Well done",
        "event_key": "goal:1",
        **body,
    }
    response = client.post("/notifications", json=data, headers=bearer(token))
    assert response.status_code == 201, response.text
    return response.json()


def test_create_returns_the_stored_row(client, alice):
    row = _create(
        client,
        alice,
        client_id="n-1",
        type=" lowBalance ",
        title=" Low ",
        message=" Balance is low ",
        event_key=" low:2025-03 ",
        related_id="",
        metadata={"amount": "5"},
        created_at="2025-03-01T00:00:00Z",
    )
    assert row["client_id"] == "n-1"
    assert (row["type"], row["title"], row["message"]) == ("lowBalance", "Low", "Balance is low")
    assert row["event_key"] == "low:2025-03"
    assert row["related_id"] is None
    assert row["metadata"] == {"amount": "5"}
    assert row["is_read"] is False
    assert row["created_at"].startswith("2025-03-01T00:00:00")


def test_one_notification_per_event_key(client, alice):
    first = _create(client, alice, client_id="n-1")
    by_event = _create(client, alice, client_id="n-2", title="again")
    by_client = _create(client, alice, client_id="n-1", event_key="other")
    assert by_event["id"] == by_client["id"] == first["id"]
    assert by_event["title"] == "Goal reached"
    assert len(client.get("/notifications", headers=bearer(alice)).json()) == 1


@pytest.mark.parametrize(
    "change",
    [
        {"title": ""},
        {"type": ""},
        {"message": ""},
        {"event_key": ""},
        {"title": "t" * 256},
        {"metadata": {"count": 3}},
    ],
)
def test_create_validates_its_input(client, alice, change):
    body = {"type": "t", "title": "t", "message": "m", "event_key": "e", **change}
    assert client.post("/notifications", json=body, headers=bearer(alice)).status_code == 422


def test_list_is_newest_first(client, alice):
    _create(client, alice, event_key="a", created_at="2025-01-01T00:00:00Z")
    _create(client, alice, event_key="b", created_at="2025-02-01T00:00:00Z")
    listed = client.get("/notifications", headers=bearer(alice)).json()
    assert [row["event_key"] for row in listed] == ["b", "a"]


def test_read_state(client, alice):
    first = _create(client, alice, event_key="a")
    _create(client, alice, event_key="b")
    path = f"/notifications/{first['id']}"
    assert client.patch(path, json={"is_read": True}, headers=bearer(alice)).json()["is_read"] is True
    assert client.get(path, headers=bearer(alice)).json()["is_read"] is True
    # A body without is_read changes nothing.
    assert client.patch(path, json={}, headers=bearer(alice)).json()["is_read"] is True

    marked = client.post("/notifications/mark-all-read", headers=bearer(alice))
    assert marked.status_code == 200
    assert [row["is_read"] for row in marked.json()] == [True, True]


def test_delete_one_and_clear_all(client, alice):
    first = _create(client, alice, client_id="n-1", event_key="a")
    _create(client, alice, client_id="n-2", event_key="b")
    _create(client, alice, client_id="n-3", event_key="c")

    assert client.delete(f"/notifications/{first['id']}", headers=bearer(alice)).status_code == 204
    assert client.get(f"/notifications/{first['id']}", headers=bearer(alice)).status_code == 404
    assert len(client.get("/notifications", headers=bearer(alice)).json()) == 2

    assert client.delete("/notifications", headers=bearer(alice)).status_code == 204
    assert client.get("/notifications", headers=bearer(alice)).json() == []
    assert sorted(deleted_ids(sync(client, alice)["notifications"])) == ["n-1", "n-2", "n-3"]


def test_accounts_are_isolated(client, alice, bob):
    row = _create(client, alice, client_id="n-1")
    # Same event key for Bob is his own notification.
    mine = _create(client, bob, client_id="n-1")
    assert mine["id"] != row["id"]

    path = f"/notifications/{row['id']}"
    assert client.get(path, headers=bearer(bob)).status_code == 404
    assert client.patch(path, json={"is_read": True}, headers=bearer(bob)).status_code == 404
    assert client.delete(path, headers=bearer(bob)).status_code == 404
    client.post("/notifications/mark-all-read", headers=bearer(bob))
    client.delete("/notifications", headers=bearer(bob))
    alice_rows = client.get("/notifications", headers=bearer(alice)).json()
    assert [(r["id"], r["is_read"]) for r in alice_rows] == [(row["id"], False)]


@pytest.mark.parametrize(
    "method, path",
    [
        ("get", "/notifications"),
        ("post", "/notifications"),
        ("delete", "/notifications"),
        ("post", "/notifications/mark-all-read"),
        ("get", "/notifications/1"),
        ("patch", "/notifications/1"),
        ("delete", "/notifications/1"),
    ],
)
def test_every_route_needs_a_token(client, method, path):
    kwargs = {"json": {}} if method in ("post", "patch") else {}
    assert getattr(client, method)(path, **kwargs).status_code == 401
