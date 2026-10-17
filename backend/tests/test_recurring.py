"""/recurring-expenses: scheduled expenses the app deducts on their due date.

The API speaks in units (day, week, month); the table stores periods
(daily, weekly, monthly).
"""

import pytest

from conftest import bearer, deleted_ids, sync


def _create(client, token, **body):
    data = {"amount": "9", "category": "bills", "unit": "month", **body}
    response = client.post("/recurring-expenses", json=data, headers=bearer(token))
    assert response.status_code == 201, response.text
    return response.json()


def test_create_returns_the_stored_row(client, alice):
    row = _create(
        client,
        alice,
        client_id="r-1",
        amount="15",
        category="  rent ",
        payment_method="card",
        note="",
        unit="weekly",
        interval_count=2,
        next_due_at="2025-04-01T00:00:00Z",
        enabled=False,
    )
    assert row["client_id"] == "r-1"
    assert row["amount"] == "15.00"
    assert row["category"] == "rent"
    assert row["payment_method"] == "card"
    assert row["note"] is None
    assert row["unit"] == "week"
    assert row["interval_count"] == 2
    assert row["next_due_at"].startswith("2025-04-01T00:00:00")
    assert row["enabled"] is False
    assert row["currency_code"] == "SYP"


@pytest.mark.parametrize("unit, expected", [("day", "day"), ("daily", "day"), ("month", "month")])
def test_units_and_periods_map_both_ways(client, alice, unit, expected):
    assert _create(client, alice, unit=unit)["unit"] == expected


def test_create_is_idempotent_by_client_id(client, alice):
    first = _create(client, alice, client_id="r-1", amount="1")
    again = _create(client, alice, client_id="r-1", amount="2")
    assert again["id"] == first["id"]
    assert again["amount"] == "1.00"


@pytest.mark.parametrize(
    "change",
    [
        {"unit": "year"},
        {"unit": None},
        {"interval_count": 0},
        {"amount": "0"},
        {"category": "   "},
        {"category": "c" * 101},
        {"note": "n" * 256},
    ],
)
def test_create_validates_its_input(client, alice, change):
    body = {"amount": "9", "category": "bills", "unit": "month", **change}
    response = client.post("/recurring-expenses", json=body, headers=bearer(alice))
    assert response.status_code == 422


def test_list_get_update_and_delete(client, alice):
    row = _create(client, alice, client_id="r-1")
    listed = client.get("/recurring-expenses", headers=bearer(alice)).json()
    assert [item["client_id"] for item in listed] == ["r-1"]
    assert client.get(f"/recurring-expenses/{row['id']}", headers=bearer(alice)).json() == row

    patched = client.patch(
        f"/recurring-expenses/{row['id']}",
        json={
            "amount": "20",
            "category": " water ",
            "unit": "day",
            "interval_count": 3,
            "enabled": False,
            "note": "monthly bill",
        },
        headers=bearer(alice),
    )
    assert patched.status_code == 200
    body = patched.json()
    assert (body["amount"], body["category"], body["unit"]) == ("20.00", "water", "day")
    assert (body["interval_count"], body["enabled"], body["note"]) == (3, False, "monthly bill")

    assert client.patch(
        f"/recurring-expenses/{row['id']}", json={"unit": "fortnight"}, headers=bearer(alice)
    ).status_code == 422

    assert client.delete(f"/recurring-expenses/{row['id']}", headers=bearer(alice)).status_code == 204
    assert client.get(f"/recurring-expenses/{row['id']}", headers=bearer(alice)).status_code == 404
    assert client.get("/recurring-expenses", headers=bearer(alice)).json() == []
    assert deleted_ids(sync(client, alice)["recurring_expenses"]) == ["r-1"]


def test_accounts_are_isolated(client, alice, bob):
    row = _create(client, alice)
    assert client.get(f"/recurring-expenses/{row['id']}", headers=bearer(bob)).status_code == 404
    assert client.patch(
        f"/recurring-expenses/{row['id']}", json={"amount": "1"}, headers=bearer(bob)
    ).status_code == 404
    assert client.delete(f"/recurring-expenses/{row['id']}", headers=bearer(bob)).status_code == 404
    assert client.get("/recurring-expenses", headers=bearer(bob)).json() == []
    assert client.get(f"/recurring-expenses/{row['id']}", headers=bearer(alice)).status_code == 200


@pytest.mark.parametrize(
    "method, path",
    [
        ("get", "/recurring-expenses"),
        ("post", "/recurring-expenses"),
        ("get", "/recurring-expenses/1"),
        ("patch", "/recurring-expenses/1"),
        ("delete", "/recurring-expenses/1"),
    ],
)
def test_every_route_needs_a_token(client, method, path):
    kwargs = {"json": {}} if method in ("post", "patch") else {}
    assert getattr(client, method)(path, **kwargs).status_code == 401
