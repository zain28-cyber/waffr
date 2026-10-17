"""/savings-goals and /savings-transfers: goals, money moved into and out of
them, and the saved amount the server derives from those transfers.
"""

import pytest

from conftest import bearer, deleted_ids, sync


def _goal(client, token, **body):
    data = {"name": "car", "target_amount": "100", **body}
    response = client.post("/savings-goals", json=data, headers=bearer(token))
    assert response.status_code == 201, response.text
    return response.json()


def _transfer(client, token, **body):
    data = {"amount": "10", "kind": "manual", **body}
    response = client.post("/savings-transfers", json=data, headers=bearer(token))
    assert response.status_code == 201, response.text
    return response.json()


# Goals


def test_create_goal_returns_the_stored_row(client, alice):
    goal = _goal(
        client,
        alice,
        client_id="g-1",
        name="  trip ",
        target_amount="250.5",
        duration="threeMonths",
        deadline="2025-12-31T00:00:00Z",
        allocate_percent="10",
    )
    assert goal["client_id"] == "g-1"
    assert goal["name"] == "trip"
    assert goal["target_amount"] == "250.50"
    assert goal["saved_amount"] == "0.00"
    assert goal["duration"] == "threeMonths"
    assert goal["allocate_percent"] == "10.00"
    # allocate_amount is only kept for periodic goals.
    assert goal["allocate_amount"] is None
    assert goal["is_completed"] is False
    assert goal["priority"] == 0


def test_priority_defaults_to_the_goal_count(client, alice):
    _goal(client, alice, client_id="a")
    second = _goal(client, alice, client_id="b")
    first_place = _goal(client, alice, client_id="c", priority=0)
    assert second["priority"] == 1
    listed = client.get("/savings-goals", headers=bearer(alice)).json()
    # Ordered by priority, then id.
    assert [goal["client_id"] for goal in listed] == ["a", "c", "b"]
    assert first_place["priority"] == 0


def test_create_goal_is_idempotent_by_client_id(client, alice):
    first = _goal(client, alice, client_id="g-1", name="first")
    again = _goal(client, alice, client_id="g-1", name="second")
    assert again["id"] == first["id"]
    assert again["name"] == "first"


@pytest.mark.parametrize(
    "change, detail",
    [
        ({"allocate_amount": None}, "allocate_amount"),
        ({"allocate_amount": "0"}, "allocate_amount"),
        ({"deduct_frequency": "none"}, "deduct frequency"),
        ({"duration_count": None}, "duration_count"),
    ],
)
def test_periodic_goals_need_a_complete_plan(client, alice, change, detail):
    body = {
        "name": "plan",
        "target_amount": "100",
        "is_periodic": True,
        "allocate_amount": "10",
        "deduct_frequency": "monthly",
        "duration_count": 10,
        **change,
    }
    response = client.post("/savings-goals", json=body, headers=bearer(alice))
    assert response.status_code == 422
    assert detail in response.json()["detail"]


def test_periodic_goal_keeps_its_allocation(client, alice):
    goal = _goal(
        client,
        alice,
        is_periodic=True,
        allocate_amount="10",
        deduct_frequency="weekly",
        duration_count=10,
    )
    assert goal["allocate_amount"] == "10.00"
    assert goal["is_periodic"] is True


@pytest.mark.parametrize(
    "change",
    [
        {"name": "   "},
        {"target_amount": "0"},
        {"duration": "decade"},
        {"deduct_frequency": "daily"},
        {"priority": -1},
        {"duration_count": 0},
        {"name": "n" * 101},
    ],
)
def test_create_goal_validates_its_input(client, alice, change):
    body = {"name": "car", "target_amount": "100", **change}
    assert client.post("/savings-goals", json=body, headers=bearer(alice)).status_code == 422


def test_saved_amount_adds_deposits_and_subtracts_withdrawals(client, alice):
    goal = _goal(client, alice)
    _transfer(client, alice, goal_id=goal["id"], amount="30")
    _transfer(client, alice, goal_id=goal["id"], amount="15.5", kind="goalPeriodic")
    removed = _transfer(client, alice, goal_id=goal["id"], amount="100")
    _transfer(client, alice, goal_id=goal["id"], amount="5", kind="withdraw")
    # Money not tied to this goal does not count.
    _transfer(client, alice, amount="1000")
    client.delete(f"/savings-transfers/{removed['id']}", headers=bearer(alice))

    fetched = client.get(f"/savings-goals/{goal['id']}", headers=bearer(alice)).json()
    assert fetched["saved_amount"] == "40.50"


def test_saved_amount_never_goes_below_zero(client, alice):
    goal = _goal(client, alice)
    _transfer(client, alice, goal_id=goal["id"], amount="5", direction="to_balance")
    assert client.get(f"/savings-goals/{goal['id']}", headers=bearer(alice)).json()["saved_amount"] == "0.00"


def test_completed_goal_reports_its_completed_amount(client, alice):
    goal = _goal(client, alice)
    _transfer(client, alice, goal_id=goal["id"], amount="30")
    done = client.patch(
        f"/savings-goals/{goal['id']}",
        json={"completed_at": "2025-03-01T00:00:00Z", "completed_amount": "120"},
        headers=bearer(alice),
    ).json()
    assert done["is_completed"] is True
    assert done["saved_amount"] == "120.00"


def test_update_goal_completion_flags(client, alice):
    goal = _goal(client, alice)
    done = client.patch(
        f"/savings-goals/{goal['id']}", json={"is_completed": True}, headers=bearer(alice)
    ).json()
    assert done["is_completed"] is True
    assert done["completed_at"] is not None

    reopened = client.patch(
        f"/savings-goals/{goal['id']}",
        json={"is_completed": False, "name": " renamed "},
        headers=bearer(alice),
    ).json()
    assert reopened["is_completed"] is False
    assert reopened["completed_at"] is None
    assert reopened["completed_amount"] is None
    assert reopened["name"] == "renamed"

    assert client.patch(
        f"/savings-goals/{goal['id']}", json={"target_amount": "0"}, headers=bearer(alice)
    ).status_code == 422


def test_delete_goal(client, alice):
    goal = _goal(client, alice, client_id="g-1")
    assert client.delete(f"/savings-goals/{goal['id']}", headers=bearer(alice)).status_code == 204
    assert client.get(f"/savings-goals/{goal['id']}", headers=bearer(alice)).status_code == 404
    assert client.get("/savings-goals", headers=bearer(alice)).json() == []
    assert deleted_ids(sync(client, alice)["savings_goals"]) == ["g-1"]


# Transfers


def test_create_transfer_finds_the_goal_by_client_id(client, alice):
    goal = _goal(client, alice, client_id="g-1")
    transfer = _transfer(
        client,
        alice,
        client_id="t-1",
        goal_client_id="g-1",
        amount="12",
        note=" first ",
        occurred_at="2025-03-01T00:00:00Z",
        processed_period_key="m:2025-03",
    )
    assert transfer["goal_id"] == goal["id"]
    assert transfer["direction"] == "to_savings"
    assert transfer["kind"] == "manual"
    assert transfer["note"] == "first"
    assert transfer["amount"] == "12.00"
    assert transfer["processed_period_key"] == "m:2025-03"


@pytest.mark.parametrize(
    "kind, direction, expected",
    [
        ("withdraw", None, "to_balance"),
        ("periodLeftover", None, "to_savings"),
        (None, "to_balance", "to_balance"),
        ("manual", "to_balance", "to_balance"),
    ],
)
def test_direction_comes_from_kind_unless_given(client, alice, kind, direction, expected):
    body = {"amount": "1", "kind": kind, "direction": direction}
    response = client.post("/savings-transfers", json=body, headers=bearer(alice))
    assert response.status_code == 201
    assert response.json()["direction"] == expected


def test_transfer_needs_a_direction_or_kind(client, alice):
    response = client.post("/savings-transfers", json={"amount": "1"}, headers=bearer(alice))
    assert response.status_code == 422


@pytest.mark.parametrize(
    "body",
    [
        {"amount": "0", "kind": "manual"},
        {"amount": "1", "kind": "gift"},
        {"amount": "1", "direction": "sideways"},
        {"amount": "1", "kind": "manual", "note": "n" * 256},
    ],
)
def test_create_transfer_validates_its_input(client, alice, body):
    assert client.post("/savings-transfers", json=body, headers=bearer(alice)).status_code == 422


def test_transfer_to_a_missing_goal_is_refused(client, alice):
    assert client.post(
        "/savings-transfers",
        json={"amount": "1", "kind": "manual", "goal_client_id": "nope"},
        headers=bearer(alice),
    ).status_code == 404
    assert client.post(
        "/savings-transfers",
        json={"amount": "1", "kind": "manual", "goal_id": 999999},
        headers=bearer(alice),
    ).status_code == 404


def test_transfer_list_get_and_delete(client, alice):
    first = _transfer(client, alice, client_id="t-old", occurred_at="2025-01-01T00:00:00Z")
    _transfer(client, alice, client_id="t-new", occurred_at="2025-02-01T00:00:00Z")
    listed = client.get("/savings-transfers", headers=bearer(alice)).json()
    assert [row["client_id"] for row in listed] == ["t-new", "t-old"]
    assert client.get(f"/savings-transfers/{first['id']}", headers=bearer(alice)).json() == first
    again = _transfer(client, alice, client_id="t-old", amount="999")
    assert again["id"] == first["id"]

    assert client.delete(f"/savings-transfers/{first['id']}", headers=bearer(alice)).status_code == 204
    assert client.get(f"/savings-transfers/{first['id']}", headers=bearer(alice)).status_code == 404
    assert [row["client_id"] for row in client.get("/savings-transfers", headers=bearer(alice)).json()] == ["t-new"]
    assert deleted_ids(sync(client, alice)["savings_transfers"]) == ["t-old"]


# Isolation


def test_accounts_are_isolated(client, alice, bob):
    goal = _goal(client, alice, client_id="g-1")
    transfer = _transfer(client, alice, goal_id=goal["id"])

    assert client.get(f"/savings-goals/{goal['id']}", headers=bearer(bob)).status_code == 404
    assert client.patch(
        f"/savings-goals/{goal['id']}", json={"name": "mine"}, headers=bearer(bob)
    ).status_code == 404
    assert client.delete(f"/savings-goals/{goal['id']}", headers=bearer(bob)).status_code == 404
    assert client.get(f"/savings-transfers/{transfer['id']}", headers=bearer(bob)).status_code == 404
    assert client.delete(f"/savings-transfers/{transfer['id']}", headers=bearer(bob)).status_code == 404
    # Bob cannot pay into Alice's goal by id or by client id.
    assert client.post(
        "/savings-transfers",
        json={"amount": "1", "kind": "manual", "goal_id": goal["id"]},
        headers=bearer(bob),
    ).status_code == 404
    assert client.post(
        "/savings-transfers",
        json={"amount": "1", "kind": "manual", "goal_client_id": "g-1"},
        headers=bearer(bob),
    ).status_code == 404
    assert client.get("/savings-goals", headers=bearer(bob)).json() == []
    assert client.get("/savings-transfers", headers=bearer(bob)).json() == []
    assert client.get(f"/savings-goals/{goal['id']}", headers=bearer(alice)).json()["saved_amount"] == "10.00"


@pytest.mark.parametrize(
    "method, path",
    [
        ("get", "/savings-goals"),
        ("post", "/savings-goals"),
        ("get", "/savings-goals/1"),
        ("patch", "/savings-goals/1"),
        ("delete", "/savings-goals/1"),
        ("get", "/savings-transfers"),
        ("post", "/savings-transfers"),
        ("get", "/savings-transfers/1"),
        ("delete", "/savings-transfers/1"),
    ],
)
def test_every_route_needs_a_token(client, method, path):
    kwargs = {"json": {}} if method in ("post", "patch") else {}
    assert getattr(client, method)(path, **kwargs).status_code == 401
