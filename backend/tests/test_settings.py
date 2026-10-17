"""/settings: the REST view of a user's settings row, which /sync shares.

The sync side, with its timestamp and streak merge rules, is covered in
test_sync_settings.py.
"""

import pytest

from conftest import bearer, sync


def test_defaults(client, alice):
    response = client.get("/settings", headers=bearer(alice))
    assert response.status_code == 200
    body = response.json()
    assert body["notifications_enabled"] is True
    assert body["notifications_muted"] is False
    for flag in (
        "notify_low_balance",
        "notify_spending_threshold",
        "notify_goal_reached",
        "notify_recurring_expense",
    ):
        assert body[flag] is True
    assert body["ai_data_enabled"] is False
    assert body["monthly_income_amount"] is None
    assert body["weekly_income_amount"] is None
    assert body["income_overrides_by_currency"] == {}
    assert body["enabled_currencies"] == ["SYP"]
    assert body["active_currency"] == "SYP"
    assert body["processed_period_keys"] == []


def test_update_changes_only_the_fields_sent(client, alice):
    response = client.patch(
        "/settings",
        json={
            "notifications_muted": True,
            "notify_goal_reached": False,
            "ai_data_enabled": True,
            "monthly_income_amount": "800",
            "processed_period_keys": ["m:2025-01"],
        },
        headers=bearer(alice),
    )
    assert response.status_code == 200
    body = response.json()
    assert body["notifications_enabled"] is False
    assert body["notifications_muted"] is True
    assert body["notify_goal_reached"] is False
    assert body["notify_low_balance"] is True
    assert body["ai_data_enabled"] is True
    assert body["monthly_income_amount"] == "800.00"
    assert body["processed_period_keys"] == ["m:2025-01"]

    # The list is replaced, not merged; null clears the income.
    again = client.patch(
        "/settings",
        json={"processed_period_keys": ["m:2025-02"], "monthly_income_amount": None},
        headers=bearer(alice),
    ).json()
    assert again["processed_period_keys"] == ["m:2025-02"]
    assert again["monthly_income_amount"] is None
    assert again["notify_goal_reached"] is False


def test_enabled_wins_over_muted_when_both_are_sent(client, alice):
    body = client.patch(
        "/settings",
        json={"notifications_muted": True, "notifications_enabled": True},
        headers=bearer(alice),
    ).json()
    assert body["notifications_enabled"] is True


@pytest.mark.parametrize(
    "body",
    [
        {"monthly_income_amount": "-1"},
        {"weekly_income_amount": "1e20"},
        {"notify_low_balance": "sometimes"},
    ],
)
def test_update_validates_its_input(client, alice, body):
    assert client.patch("/settings", json=body, headers=bearer(alice)).status_code == 422


def test_rest_and_sync_share_one_row(client, alice):
    client.patch("/settings", json={"weekly_income_amount": "50"}, headers=bearer(alice))
    assert sync(client, alice)["settings"]["weekly_income_amount"] == "50.00"


def test_a_missing_settings_row_is_created_on_read(client, alice):
    from conftest import system_execute, system_scalar

    system_execute("DELETE FROM user_settings")
    assert client.get("/settings", headers=bearer(alice)).status_code == 200
    assert system_scalar("SELECT count(*) FROM user_settings") == 1


def test_accounts_are_isolated(client, alice, bob):
    client.patch("/settings", json={"notifications_muted": True}, headers=bearer(alice))
    assert client.get("/settings", headers=bearer(bob)).json()["notifications_enabled"] is True
    assert client.get("/settings", headers=bearer(alice)).json()["notifications_enabled"] is False


@pytest.mark.parametrize("method", ["get", "patch"])
def test_every_route_needs_a_token(client, method):
    kwargs = {"json": {}} if method == "patch" else {}
    assert getattr(client, method)("/settings", **kwargs).status_code == 401
