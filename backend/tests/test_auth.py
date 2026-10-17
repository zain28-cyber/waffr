"""Accounts and tokens: sign-up, sign-in, tokens, data key, password change
and reset, account deletion and the legacy photo endpoints.

Throttling and lockout basics live in test_api_security.py; this file covers
the rest of the /auth surface.
"""

from datetime import datetime, timedelta, timezone

import jwt
import pytest

from conftest import bearer, ids, register, sync, system_execute, system_scalar

DATA_KEY = {"salt": "s" * 16, "iterations": 100_000, "wrapped_key": "w" * 40}


def _token(**claims) -> str:
    import auth

    return jwt.encode(claims, auth.SECRET_KEY, algorithm="HS256")


def _soon() -> datetime:
    return datetime.now(timezone.utc) + timedelta(hours=1)


# Health check


def test_root_answers_without_a_token(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Waffr API is running"}


# Sign-up


def test_register_returns_a_working_bearer_token(client):
    response = client.post(
        "/auth/register",
        json={"email": "alice@example.com", "password": "correct horse 1"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    me = client.get("/auth/me", headers=bearer(body["access_token"]))
    assert me.status_code == 200
    assert me.json()["email"] == "alice@example.com"


def test_register_stores_the_profile_trimmed(client):
    token = register(
        client,
        "alice@example.com",
        name="  Alice  ",
        gender="female",
        birthdate="1990-05-01",
        country=" Syria ",
        city="Damascus",
        street="",
        phone="+963 912345678",
    )
    me = client.get("/auth/me", headers=bearer(token)).json()
    assert me["name"] == "Alice"
    assert me["gender"] == "female"
    assert me["birthdate"] == "1990-05-01"
    assert me["country"] == "Syria"
    assert me["city"] == "Damascus"
    assert me["street"] is None
    assert me["phone"] == "+963 912345678"
    assert me["data_key"] is None
    assert me["has_photo"] is False
    # Gender and birthdate are mirrored into the synced settings.
    settings = sync(client, token)["settings"]
    assert settings["gender"] == "female"
    assert settings["birthdate"] == "1990-05-01"


def test_register_creates_default_settings(client, alice):
    settings = client.get("/settings", headers=bearer(alice)).json()
    assert settings["notifications_enabled"] is True
    assert settings["processed_period_keys"] == []
    assert settings["enabled_currencies"] == ["SYP"]
    assert system_scalar("SELECT count(*) FROM user_settings") == 1


def test_register_refuses_a_taken_email(client, alice):
    response = client.post(
        "/auth/register",
        json={"email": "alice@example.com", "password": "another password"},
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "Email already registered"
    assert system_scalar("SELECT count(*) FROM users") == 1


@pytest.mark.parametrize(
    "body",
    [
        {"email": "not-an-email", "password": "long enough"},
        {"email": "a@example.com", "password": "short"},
        {"email": "a@example.com", "password": "x" * 257},
        {"email": "a@example.com", "password": "long enough", "gender": "other"},
        # From the old live sync script: a malformed phone is refused.
        {"email": "a@example.com", "password": "long enough", "phone": "0912"},
        {"email": "a@example.com", "password": "long enough", "name": "n" * 101},
        {"password": "long enough"},
    ],
)
def test_register_validates_its_input(client, body):
    assert client.post("/auth/register", json=body).status_code == 422
    assert system_scalar("SELECT count(*) FROM users") == 0


# Sign-in


def test_login_with_the_right_password(client):
    register(client, "alice@example.com", password="right password")
    response = client.post(
        "/auth/login", json={"email": "alice@example.com", "password": "right password"}
    )
    assert response.status_code == 200
    token = response.json()["access_token"]
    assert client.get("/auth/me", headers=bearer(token)).json()["email"] == "alice@example.com"


def test_login_failures_look_the_same_for_known_and_unknown_emails(client):
    register(client, "alice@example.com", password="right password")
    wrong = client.post(
        "/auth/login", json={"email": "alice@example.com", "password": "wrong password"}
    )
    unknown = client.post(
        "/auth/login", json={"email": "nobody@example.com", "password": "wrong password"}
    )
    assert wrong.status_code == unknown.status_code == 401
    assert wrong.json() == unknown.json() == {"detail": "Invalid email or password"}


def test_login_validates_its_input(client):
    assert client.post("/auth/login", json={"email": "x", "password": "p"}).status_code == 422
    assert (
        client.post(
            "/auth/login", json={"email": "a@example.com", "password": "p" * 257}
        ).status_code
        == 422
    )


def test_lockout_ends_when_its_time_is_up(client):
    from rate_limit import limiter

    register(client, "alice@example.com", password="right password")
    for _ in range(5):
        client.post("/auth/login", json={"email": "alice@example.com", "password": "bad one!"})
    system_execute("UPDATE users SET locked_until = now() - interval '1 minute'")
    # The per-email failure counter would still refuse; a restart clears it.
    limiter.clear()
    response = client.post(
        "/auth/login", json={"email": "alice@example.com", "password": "right password"}
    )
    assert response.status_code == 200
    assert system_scalar("SELECT locked_until IS NULL FROM users") is True


# Tokens


def test_tokens_last_seven_days(client, alice):
    import auth

    claims = jwt.decode(alice, auth.SECRET_KEY, algorithms=["HS256"])
    assert claims["exp"] - claims["iat"] == 7 * 24 * 60 * 60
    assert claims["ver"] == 0
    assert claims["sub"] == str(system_scalar("SELECT id FROM users"))


def test_requests_without_a_token_are_refused(client):
    response = client.get("/auth/me")
    assert response.status_code == 401
    assert response.json()["detail"] == "Not authenticated"
    basic = client.get("/auth/me", headers={"Authorization": "Basic YTpi"})
    assert basic.status_code == 401


def test_expired_tokens_are_refused(client, alice):
    user_id = system_scalar("SELECT id FROM users")
    expired = _token(
        sub=str(user_id), ver=0, exp=datetime.now(timezone.utc) - timedelta(seconds=5)
    )
    response = client.get("/auth/me", headers=bearer(expired))
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid or expired token"


@pytest.mark.parametrize(
    "claims",
    [
        {"sub": "999999", "ver": 0},  # no such account
        {"sub": "1", "ver": 1},  # older version than the account's
        {"sub": "abc", "ver": 0},  # not an id
        {"ver": 0},  # no subject
    ],
)
def test_tokens_for_the_wrong_account_or_version_are_refused(client, alice, claims):
    token = _token(**claims, exp=_soon())
    assert client.get("/auth/me", headers=bearer(token)).status_code == 401


def test_a_hand_made_token_with_the_right_claims_works(client, alice):
    user_id = system_scalar("SELECT id FROM users")
    token = _token(sub=str(user_id), ver=0, exp=_soon())
    assert client.get("/auth/me", headers=bearer(token)).status_code == 200


# Data key


def test_data_key_is_stored_once(client, alice):
    stored = client.put("/auth/key", json=DATA_KEY, headers=bearer(alice))
    assert stored.status_code == 200
    assert stored.json() == {"data_key": DATA_KEY}
    assert client.get("/auth/me", headers=bearer(alice)).json()["data_key"] == DATA_KEY

    again = client.put(
        "/auth/key", json={**DATA_KEY, "wrapped_key": "z" * 40}, headers=bearer(alice)
    )
    assert again.status_code == 409
    assert client.get("/auth/me", headers=bearer(alice)).json()["data_key"] == DATA_KEY


@pytest.mark.parametrize(
    "change",
    [
        {"salt": "short"},
        {"iterations": 99_999},
        {"iterations": 10_000_001},
        {"wrapped_key": "w" * 39},
    ],
)
def test_data_key_is_validated(client, alice, change):
    response = client.put("/auth/key", json={**DATA_KEY, **change}, headers=bearer(alice))
    assert response.status_code == 422


def test_data_key_needs_a_token(client):
    assert client.put("/auth/key", json=DATA_KEY).status_code == 401


# Password change


def test_password_change_needs_the_current_password(client):
    token = register(client, "alice@example.com", password="first password")
    response = client.post(
        "/auth/password/change",
        json={"current_password": "not it at all", "new_password": "second password"},
        headers=bearer(token),
    )
    assert response.status_code == 400
    assert client.get("/auth/me", headers=bearer(token)).status_code == 200


def test_password_change_validates_the_new_password(client):
    token = register(client, "alice@example.com", password="first password")
    response = client.post(
        "/auth/password/change",
        json={"current_password": "first password", "new_password": "short"},
        headers=bearer(token),
    )
    assert response.status_code == 422


def test_password_change_rewraps_an_existing_data_key(client):
    token = register(client, "alice@example.com", password="first password")
    client.put("/auth/key", json=DATA_KEY, headers=bearer(token))
    missing = client.post(
        "/auth/password/change",
        json={"current_password": "first password", "new_password": "second password"},
        headers=bearer(token),
    )
    assert missing.status_code == 400
    assert missing.json()["detail"] == "Data key is required"

    rewrapped = {**DATA_KEY, "wrapped_key": "r" * 40}
    changed = client.post(
        "/auth/password/change",
        json={
            "current_password": "first password",
            "new_password": "second password",
            "data_key": rewrapped,
        },
        headers=bearer(token),
    )
    assert changed.status_code == 200
    fresh = changed.json()["access_token"]
    assert client.get("/auth/me", headers=bearer(fresh)).json()["data_key"] == rewrapped
    login = client.post(
        "/auth/login", json={"email": "alice@example.com", "password": "second password"}
    )
    assert login.status_code == 200


def test_password_change_needs_a_token(client):
    response = client.post(
        "/auth/password/change",
        json={"current_password": "a", "new_password": "long enough"},
    )
    assert response.status_code == 401


# Password reset


def test_forgot_password_needs_email_configured(client, monkeypatch):
    monkeypatch.delenv("SMTP_HOST")
    response = client.post("/auth/password/forgot", json={"email": "alice@example.com"})
    assert response.status_code == 503


def test_forgot_password_validates_the_email(client):
    assert client.post("/auth/password/forgot", json={"email": "nope"}).status_code == 422


def test_a_fresh_code_is_not_resent_straight_away(client, monkeypatch):
    import password_reset

    sent: list[tuple[str, str]] = []
    monkeypatch.setattr(password_reset, "send_code", lambda to, code: sent.append((to, code)))
    register(client, "alice@example.com")
    client.post("/auth/password/forgot", json={"email": "alice@example.com"})
    client.post("/auth/password/forgot", json={"email": "alice@example.com"})
    assert len(sent) == 1


def test_a_failed_email_can_be_retried_at_once(client, monkeypatch):
    import password_reset

    register(client, "alice@example.com")
    # The default fake send fails: the code is dropped again.
    assert client.post("/auth/password/forgot", json={"email": "alice@example.com"}).status_code == 200
    assert system_scalar("SELECT reset_code_hash IS NULL AND reset_code_sent_at IS NULL FROM users")

    sent: dict[str, str] = {}
    monkeypatch.setattr(password_reset, "send_code", lambda to, code: sent.__setitem__(to, code))
    client.post("/auth/password/forgot", json={"email": "alice@example.com"})
    assert list(sent) == ["alice@example.com"]
    assert len(sent["alice@example.com"]) == 6


def test_reset_code_stops_working_after_five_wrong_tries(client, sent_codes):
    register(client, "alice@example.com", password="old password")
    client.post("/auth/password/forgot", json={"email": "alice@example.com"})
    code = sent_codes["alice@example.com"]
    wrong = "000000" if code != "000000" else "111111"
    for _ in range(5):
        response = client.post(
            "/auth/password/reset",
            json={"email": "alice@example.com", "code": wrong, "new_password": "new password"},
        )
        assert response.status_code == 400
    blocked = client.post(
        "/auth/password/reset",
        json={"email": "alice@example.com", "code": code, "new_password": "new password"},
    )
    assert blocked.status_code == 400
    old_login = client.post(
        "/auth/login", json={"email": "alice@example.com", "password": "old password"}
    )
    assert old_login.status_code == 200


def test_reset_for_an_unknown_email_fails_like_a_wrong_code(client):
    response = client.post(
        "/auth/password/reset",
        json={"email": "nobody@example.com", "code": "123456", "new_password": "new password"},
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "Invalid or expired code"


@pytest.mark.parametrize("code", ["12345", "1234567", "12345a"])
def test_reset_code_must_be_six_digits(client, code):
    response = client.post(
        "/auth/password/reset",
        json={"email": "alice@example.com", "code": code, "new_password": "new password"},
    )
    assert response.status_code == 422


def test_reset_drops_the_data_key_and_sealed_text(client, sent_codes):
    token = register(client, "alice@example.com", password="old password")
    client.put("/auth/key", json=DATA_KEY, headers=bearer(token))
    sync(
        client,
        token,
        transactions=[
            {
                "client_id": "tx-1",
                "type": "expense",
                "amount": "5",
                "category": "plain food",
                "note": "enc1:sealed-note",
            }
        ],
        notifications=[
            {
                "client_id": "n-1",
                "type": "goalReached",
                "title": "enc1:title",
                "message": "plain message",
                "event_key": "goal:1",
                "metadata": {"name": "enc1:goal"},
            }
        ],
    )

    client.post("/auth/password/forgot", json={"email": "alice@example.com"})
    reset = client.post(
        "/auth/password/reset",
        json={
            "email": "alice@example.com",
            "code": sent_codes["alice@example.com"],
            "new_password": "new password",
        },
    )
    assert reset.status_code == 200

    fresh = client.post(
        "/auth/login", json={"email": "alice@example.com", "password": "new password"}
    ).json()["access_token"]
    assert client.get("/auth/me", headers=bearer(fresh)).json()["data_key"] is None
    pulled = sync(client, fresh)
    assert ids(pulled["transactions"]) == ["tx-1"]
    row = pulled["transactions"]["upserts"][0]
    assert row["note"] == ""
    assert row["category"] == "plain food"
    notification = pulled["notifications"]["upserts"][0]
    assert notification["title"] == ""
    assert notification["message"] == "plain message"
    assert notification["metadata"] == {}


# Account deletion


def test_delete_account_needs_a_token(client):
    assert client.delete("/auth/account").status_code == 401


def test_a_deleted_email_can_sign_up_again(client, alice):
    assert client.delete("/auth/account", headers=bearer(alice)).status_code == 204
    fresh = register(client, "alice@example.com")
    assert client.get("/transactions", headers=bearer(fresh)).json() == []


# Profile photo leftovers for older app versions


def test_photo_endpoints_always_answer_no_photo(client, alice):
    uploaded = client.put("/auth/photo", headers=bearer(alice))
    assert uploaded.status_code == 200
    assert uploaded.json()["has_photo"] is False
    assert client.get("/auth/photo", headers=bearer(alice)).status_code == 404
    removed = client.delete("/auth/photo", headers=bearer(alice))
    assert removed.status_code == 200
    assert removed.json()["has_photo"] is False


@pytest.mark.parametrize("method", ["put", "get", "delete"])
def test_photo_endpoints_need_a_token(client, method):
    assert getattr(client, method)("/auth/photo").status_code == 401
