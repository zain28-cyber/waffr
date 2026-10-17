"""/shopping-lists and their /items: lists, items, purchase state, and the
soft deletes that cascade from a list to its items.
"""

import pytest

from conftest import bearer, deleted_ids, sync


def _list(client, token, **body):
    data = {"name": "food", **body}
    response = client.post("/shopping-lists", json=data, headers=bearer(token))
    assert response.status_code == 201, response.text
    return response.json()


def _item(client, token, list_id, **body):
    data = {"name": "milk", **body}
    response = client.post(f"/shopping-lists/{list_id}/items", json=data, headers=bearer(token))
    assert response.status_code == 201, response.text
    return response.json()


# Lists


def test_create_list(client, alice):
    shopping = _list(client, alice, client_id="l-1", name="  weekly ")
    assert shopping["client_id"] == "l-1"
    assert shopping["name"] == "weekly"
    assert shopping["items"] == []


def test_create_list_is_idempotent_by_client_id(client, alice):
    first = _list(client, alice, client_id="l-1", name="first")
    again = _list(client, alice, client_id="l-1", name="second")
    assert again["id"] == first["id"]
    assert again["name"] == "first"
    assert len(client.get("/shopping-lists", headers=bearer(alice)).json()) == 1


@pytest.mark.parametrize("body", [{"name": "   "}, {"name": "n" * 101}, {}])
def test_create_list_validates_its_input(client, alice, body):
    assert client.post("/shopping-lists", json=body, headers=bearer(alice)).status_code == 422


def test_list_get_rename_and_delete(client, alice):
    shopping = _list(client, alice, client_id="l-1")
    item = _item(client, alice, shopping["id"], client_id="i-1")

    fetched = client.get(f"/shopping-lists/{shopping['id']}", headers=bearer(alice)).json()
    assert [row["client_id"] for row in fetched["items"]] == ["i-1"]

    renamed = client.patch(
        f"/shopping-lists/{shopping['id']}", json={"name": " market "}, headers=bearer(alice)
    )
    assert renamed.status_code == 200
    assert renamed.json()["name"] == "market"
    assert client.patch(
        f"/shopping-lists/{shopping['id']}", json={"name": " "}, headers=bearer(alice)
    ).status_code == 422

    assert client.delete(f"/shopping-lists/{shopping['id']}", headers=bearer(alice)).status_code == 204
    assert client.get(f"/shopping-lists/{shopping['id']}", headers=bearer(alice)).status_code == 404
    assert client.get("/shopping-lists", headers=bearer(alice)).json() == []
    # Deleting the list deletes its items too, and other devices hear of both.
    pulled = sync(client, alice)
    assert deleted_ids(pulled["shopping_lists"]) == ["l-1"]
    assert deleted_ids(pulled["shopping_items"]) == [item["client_id"]]


# Items


def test_create_item(client, alice):
    shopping = _list(client, alice)
    item = _item(
        client,
        alice,
        shopping["id"],
        client_id="i-1",
        name=" eggs ",
        quantity=12,
        price="3.5",
        is_purchased=True,
        purchased_at="2025-03-01T00:00:00Z",
        expense_client_id="tx-9",
    )
    assert item["list_id"] == shopping["id"]
    assert item["name"] == "eggs"
    assert item["quantity"] == 12
    assert item["price"] == "3.50"
    assert item["is_purchased"] is True
    assert item["expense_client_id"] == "tx-9"


@pytest.mark.parametrize(
    "body",
    [
        {"name": "  "},
        {"name": "milk", "quantity": 0},
        {"name": "milk", "price": "-1"},
        {"name": "n" * 256},
    ],
)
def test_create_item_validates_its_input(client, alice, body):
    shopping = _list(client, alice)
    response = client.post(
        f"/shopping-lists/{shopping['id']}/items", json=body, headers=bearer(alice)
    )
    assert response.status_code == 422


def test_item_client_id_is_idempotent_within_a_list_and_unique_across_lists(client, alice):
    first_list = _list(client, alice, client_id="a")
    second_list = _list(client, alice, client_id="b")
    item = _item(client, alice, first_list["id"], client_id="i-1")
    again = _item(client, alice, first_list["id"], client_id="i-1", name="other")
    assert again["id"] == item["id"]
    clash = client.post(
        f"/shopping-lists/{second_list['id']}/items",
        json={"name": "milk", "client_id": "i-1"},
        headers=bearer(alice),
    )
    assert clash.status_code == 409


def test_items_are_newest_first(client, alice):
    shopping = _list(client, alice)
    _item(client, alice, shopping["id"], client_id="first")
    _item(client, alice, shopping["id"], client_id="second")
    listed = client.get(f"/shopping-lists/{shopping['id']}/items", headers=bearer(alice)).json()
    assert [row["client_id"] for row in listed] == ["second", "first"]


def test_unpurchasing_clears_the_purchase(client, alice):
    shopping = _list(client, alice)
    item = _item(client, alice, shopping["id"])
    path = f"/shopping-lists/{shopping['id']}/items/{item['id']}"
    bought = client.patch(
        path,
        json={"is_purchased": True, "purchased_at": "2025-03-01T00:00:00Z", "expense_client_id": "tx-1"},
        headers=bearer(alice),
    ).json()
    assert bought["is_purchased"] is True
    assert bought["expense_client_id"] == "tx-1"

    undone = client.patch(path, json={"is_purchased": False}, headers=bearer(alice)).json()
    assert undone["is_purchased"] is False
    assert undone["purchased_at"] is None
    assert undone["expense_client_id"] is None

    changed = client.patch(
        path, json={"name": " oat milk ", "quantity": 2, "price": None}, headers=bearer(alice)
    ).json()
    assert (changed["name"], changed["quantity"], changed["price"]) == ("oat milk", 2, None)
    assert client.patch(path, json={"quantity": 0}, headers=bearer(alice)).status_code == 422


def test_items_are_reached_through_their_own_list(client, alice):
    first_list = _list(client, alice, client_id="a")
    second_list = _list(client, alice, client_id="b")
    item = _item(client, alice, first_list["id"])
    wrong = f"/shopping-lists/{second_list['id']}/items/{item['id']}"
    assert client.get(wrong, headers=bearer(alice)).status_code == 404
    assert client.patch(wrong, json={"quantity": 2}, headers=bearer(alice)).status_code == 404
    assert client.delete(wrong, headers=bearer(alice)).status_code == 404


def test_delete_item(client, alice):
    shopping = _list(client, alice)
    item = _item(client, alice, shopping["id"], client_id="i-1")
    path = f"/shopping-lists/{shopping['id']}/items/{item['id']}"
    assert client.get(path, headers=bearer(alice)).json() == item
    assert client.delete(path, headers=bearer(alice)).status_code == 204
    assert client.get(path, headers=bearer(alice)).status_code == 404
    assert client.get(f"/shopping-lists/{shopping['id']}/items", headers=bearer(alice)).json() == []
    assert deleted_ids(sync(client, alice)["shopping_items"]) == ["i-1"]


# Isolation


def test_accounts_are_isolated(client, alice, bob):
    shopping = _list(client, alice)
    item = _item(client, alice, shopping["id"])
    list_path = f"/shopping-lists/{shopping['id']}"
    item_path = f"{list_path}/items/{item['id']}"

    assert client.get(list_path, headers=bearer(bob)).status_code == 404
    assert client.patch(list_path, json={"name": "mine"}, headers=bearer(bob)).status_code == 404
    assert client.delete(list_path, headers=bearer(bob)).status_code == 404
    assert client.get(f"{list_path}/items", headers=bearer(bob)).status_code == 404
    assert client.post(f"{list_path}/items", json={"name": "x"}, headers=bearer(bob)).status_code == 404
    assert client.get(item_path, headers=bearer(bob)).status_code == 404
    assert client.patch(item_path, json={"quantity": 5}, headers=bearer(bob)).status_code == 404
    assert client.delete(item_path, headers=bearer(bob)).status_code == 404
    assert client.get("/shopping-lists", headers=bearer(bob)).json() == []
    assert client.get(item_path, headers=bearer(alice)).json()["quantity"] == 1


@pytest.mark.parametrize(
    "method, path",
    [
        ("get", "/shopping-lists"),
        ("post", "/shopping-lists"),
        ("get", "/shopping-lists/1"),
        ("patch", "/shopping-lists/1"),
        ("delete", "/shopping-lists/1"),
        ("get", "/shopping-lists/1/items"),
        ("post", "/shopping-lists/1/items"),
        ("get", "/shopping-lists/1/items/1"),
        ("patch", "/shopping-lists/1/items/1"),
        ("delete", "/shopping-lists/1/items/1"),
    ],
)
def test_every_route_needs_a_token(client, method, path):
    kwargs = {"json": {}} if method in ("post", "patch") else {}
    assert getattr(client, method)(path, **kwargs).status_code == 401
