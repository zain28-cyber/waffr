"""Password hashing, access tokens, and the signed-in user dependency.

Tokens are HS256 JWTs signed with SECRET_KEY. Each carries the account's
``token_version``; bumping it (password change or reset) signs out every
older token.
"""

import logging
import os
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pwdlib import PasswordHash
from sqlalchemy import select
from sqlalchemy.orm import Session

from database import get_db
from models import User
from row_security import bind_user, system_scope

logger = logging.getLogger("waffr.security")


def _load_secret_key() -> str:
    # Render generates SECRET_KEY from render.yaml. Without one, a random key
    # is used: nobody can forge tokens, but sign-ins end on restart.
    value = (os.getenv("SECRET_KEY") or "").strip()
    if not value:
        logger.warning(
            "SECRET_KEY is not set; using a random key, so sign-ins end "
            "when the server restarts"
        )
        return secrets.token_urlsafe(48)
    if len(value) < 32:
        logger.warning("SECRET_KEY is shorter than 32 characters; use a long random value")
    return value


SECRET_KEY = _load_secret_key()
ALGORITHM = "HS256"
TOKEN_LIFETIME = timedelta(days=7)

password_hash = PasswordHash.recommended()
security = HTTPBearer(auto_error=False)

# Checked when an email has no account, so the reply takes as long as a real
# password check and does not reveal which emails are registered.
_DUMMY_HASH = password_hash.hash(secrets.token_urlsafe(16))


def hash_password(password: str) -> str:
    """Argon2 hash of [password]."""
    return password_hash.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    """True when [password] matches [hashed_password]."""
    return password_hash.verify(password, hashed_password)


def burn_password_check(password: str) -> None:
    """Spend the time of a real password check, for unknown accounts."""
    password_hash.verify(password, _DUMMY_HASH)


def create_access_token(user: User) -> str:
    """A signed token for [user], valid for TOKEN_LIFETIME."""
    now = datetime.now(timezone.utc)

    payload = {
        "sub": str(user.id),
        "ver": user.token_version,
        "iat": now,
        "exp": now + TOKEN_LIFETIME,
    }

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> tuple[int, int] | None:
    """(user id, token version) from a valid, unexpired token; else None."""
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
            options={"require": ["exp", "sub"]},
        )
        return int(payload["sub"]), int(payload.get("ver", 0))
    except (jwt.InvalidTokenError, KeyError, TypeError, ValueError):
        return None


def user_id_for_email(db: Session, email: str) -> int | None:
    """Find an account before sign-in. Row security hides users otherwise."""
    with system_scope(db):
        return db.scalar(select(User.id).where(User.email == email))


def _reject(request: Request, reason: str) -> HTTPException:
    # Imported here: security_log reads SECRET_KEY from this module.
    from security_log import log_event

    log_event("token_rejected", request=request, reason=reason)
    return HTTPException(status_code=401, detail="Invalid or expired token")


def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: Session = Depends(get_db),
):
    """FastAPI dependency: the signed-in user, or 401.

    Also binds the request's database session to that user, so row
    security limits every later query to their rows.
    """
    if credentials is None:
        raise HTTPException(
            status_code=401,
            detail="Not authenticated",
        )

    decoded = decode_token(credentials.credentials)
    if decoded is None:
        raise _reject(request, "invalid")
    user_id, version = decoded

    # From here on this request's queries only reach this user's rows.
    bind_user(db, user_id)
    user = db.get(User, user_id)

    if not user:
        raise _reject(request, "unknown_user")

    if version != user.token_version:
        raise _reject(request, "revoked")

    return user
