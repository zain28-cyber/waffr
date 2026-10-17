"""/transactions: create, list, read, update and soft-delete a user's income
and expenses, with idempotent creates and per-account isolation.
"""

import pytest

from conftest import bearer, deleted_ids, sync


def _create(client, token, **body):
    data = {"type": "expense", "amount": "10", **body}
    response = client.post("/transactions", json=data, headers=bearer(token))
    assert response.status_code == 201, response.text
    return response.json()


def test_create_returns_the_stored_row(client, alice):
    row = _create(
        client,
        alice,
        client_id="tx-1",
        amount="12.5",
        category=" food ",
        payment_method="",
        note="lunch",
        occurred_at="2025-03-01T10:00:00+02:00",
        frequency="monthly",
        period_key="m:2025-03",
    )
    assert row["client_id"] == "tx-1"
    assert row["type"] == "expense"
    assert row["amount"] == "12.50"
    assert row["currency_code"] == "SYP"
    assert row["category"] == "food"
    assert row["payment_method"] is None
    assert row["note"] == "lunch"
    assert row["occurred_at"].startswith("2025-03-01T08:00:00")
    assert row["frequency"] == "monthly"
    assert row["period_key"] == "m:2025-03"


def test_create_without_client_id_gets_one(client, alice):
    row = _create(client, alice)
    assert len(row["client_id"]) == 36
    assert row["frequency"] == "none"


def test_create_is_idempotent_by_client_id(client, alice):
    first = _create(client, alice, client_id="tx-1", amount="5")
    again = _create(client, alice, client_id="tx-1", amount="99")
    assert again["id"] == first["id"]
    assert again["amount"] == "5.00"
    assert len(client.get("/transactions", headers=bearer(alice)).json()) == 1


def test_create_is_idempotent_by_source_id(client, alice):
    first = _create(client, alice, source_id="recurring:r1:2025-03")
    again = _create(client, alice, source_id="recurring:r1:2025-03")
    assert again["id"] == first["id"]
    assert len(client.get("/transactions", headers=bearer(alice)).json()) == 1


def test_list_is_newest_first_and_filters_by_type(client, alice):
    _create(client, alice, client_id="old", occurred_at="2025-01-01T00:00:00Z")
    _create(client, alice, client_id="new", occurred_at="2025-02-01T00:00:00Z")
    _create(client, alice, client_id="pay", type="income", occurred_at="2025-01-15T00:00:00Z")

    listed = client.get("/transactions", headers=bearer(alice)).json()
    assert [row["client_id"] for row in listed] == ["new", "pay", "old"]
    incomes = client.get("/transactions?type=income", headers=bearer(alice)).json()
    assert [row["client_id"] for row in incomes] == ["pay"]
    assert client.get("/transactions?type=gift", headers=bearer(alice)).status_code == 422


def test_get_one(client, alice):
    row = _create(client, alice, note="x")
    fetched = client.get(f"/transactions/{row['id']}", headers=bearer(alice))
    assert fetched.status_code == 200
    assert fetched.json() == row
    assert client.get("/transactions/999999", headers=bearer(alice)).status_code == 404


def test_update_changes_only_the_fields_sent(client, alice):
    row = _create(client, alice, note="before", category="food", frequency="weekly")
    response = client.patch(
        f"/transactions/{row['id']}",
        json={"amount": "7.25", "note": "  ", "frequency": "none"},
        headers=bearer(alice),
    )
    assert response.status_code == 200
    updated = response.json()
    assert updated["amount"] == "7.25"
    assert updated["note"] is None
    assert updated["category"] == "food"
    assert updated["frequency"] == "none"


@pytest.mark.parametrize(
    "body",
    [{"amount": "0"}, {"amount": "-1"}, {"frequency": "daily"}, {"note": "n" * 256}],
)
def test_update_validates_its_input(client, alice, body):
    row = _create(client, alice)
    response = client.patch(f"/transactions/{row['id']}", json=body, headers=bearer(alice))
    assert response.status_code == 422


def test_delete_hides_the_row_and_tells_other_devices(client, alice):
    row = _create(client, alice, client_id="tx-1")
    assert client.delete(f"/transactions/{row['id']}", headers=bearer(alice)).status_code == 204
    assert client.get(f"/transactions/{row['id']}", headers=bearer(alice)).status_code == 404
    assert client.delete(f"/transactions/{row['id']}", headers=bearer(alice)).status_code == 404
    assert client.get("/transactions", headers=bearer(alice)).json() == []
    assert deleted_ids(sync(client, alice)["transactions"]) == ["tx-1"]


@pytest.mark.parametrize(
    "body",
    [
        {"type": "gift", "amount": "1"},
        {"type": "expense", "amount": "0"},
        {"type": "expense", "amount": "-5"},
        {"type": "expense", "amount": "1e20"},
        {"type": "expense"},
        {"type": "expense", "amount": ""},
        {"type": "expense", "amount": "1", "note": "n" * 256},
        {"type": "expense", "amount": "1", "client_id": "c" * 65},
        {"type": "expense", "amount": "1", "frequency": "yearly"},
    ],
)
def test_create_validates_its_input(client, alice, body):
    assert client.post("/transactions", json=body, headers=bearer(alice)).status_code == 422


def test_accounts_are_isolated(client, alice, bob):
    row = _create(client, alice, client_id="shared", source_id="same-source", amount="3")
    # Bob's identical ids make his own rows.
    mine = _create(client, bob, client_id="shared", source_id="same-source", amount="8")
    assert mine["id"] != row["id"]
    assert mine["amount"] == "8.00"

    for method in ("get", "delete"):
        assert getattr(client, method)(
            f"/transactions/{row['id']}", headers=bearer(bob)
        ).status_code == 404
    assert client.patch(
        f"/transactions/{row['id']}", json={"amount": "1"}, headers=bearer(bob)
    ).status_code == 404
    assert [r["amount"] for r in client.get("/transactions", headers=bearer(alice)).json()] == ["3.00"]
    assert [r["amount"] for r in client.get("/transactions", headers=bearer(bob)).json()] == ["8.00"]


@pytest.mark.parametrize(
    "method, path",
    [
        ("get", "/transactions"),
        ("post", "/transactions"),
        ("get", "/transactions/1"),
        ("patch", "/transactions/1"),
        ("delete", "/transactions/1"),
    ],
)
def test_every_route_needs_a_token(client, method, path):
    kwargs = {"json": {}} if method in ("post", "patch") else {}
    assert getattr(client, method)(path, **kwargs).status_code == 401
