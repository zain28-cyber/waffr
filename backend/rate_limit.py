"""Request rate limits, counted in this process's memory.

Every request passes the global limit in ``RateLimitMiddleware``: per account
when it carries a valid token, otherwise per IP address. Sign-in, sign-up,
password and sync routes add tighter limits of their own with ``enforce``.

Render runs one instance of the API, so one in-memory table sees every
request. With more instances or workers each keeps its own counts; move the
table to Redis before scaling out.
"""

import logging
import math
import threading
import time
from dataclasses import dataclass

from fastapi import HTTPException, Request
from starlette.responses import JSONResponse

from auth import decode_token
from client_address import client_ip
from security_log import email_tag, log_event

TOO_MANY = "Too many requests"


@dataclass(frozen=True)
class Rule:
    """At most [limit] requests per [period] seconds, refilled evenly."""

    limit: int
    period: float

    @property
    def interval(self) -> float:
        """Seconds between requests at the steady rate."""
        return self.period / self.limit


# Every request: per account, or per address without a valid token. Phones on
# one carrier can share an address, so the anonymous limit is not tight.
GLOBAL_USER = Rule(180, 60)
GLOBAL_IP = Rule(120, 60)

LOGIN_IP = Rule(30, 5 * 60)
# Wrong passwords per email, whether or not the account exists.
LOGIN_FAILURES_EMAIL = Rule(5, 15 * 60)
REGISTER_IP = Rule(10, 60 * 60)
REGISTER_ALL = Rule(300, 60 * 60)
FORGOT_IP = Rule(5, 15 * 60)
FORGOT_EMAIL = Rule(3, 60 * 60)
# Caps the outgoing mail, whatever addresses the requests come from.
FORGOT_ALL = Rule(100, 60 * 60)
RESET_IP = Rule(10, 15 * 60)
RESET_EMAIL = Rule(10, 60 * 60)
PASSWORD_CHANGE_USER = Rule(5, 15 * 60)
DATA_KEY_USER = Rule(10, 60 * 60)
ACCOUNT_DELETE_USER = Rule(3, 60 * 60)
SYNC_USER = Rule(30, 60)
NEWS_REFRESH_USER = Rule(2, 10 * 60)
NEWS_REFRESH_ALL = Rule(6, 60 * 60)

# Render's health check hits "/" every few seconds; a 429 there would get the
# service restarted.
_EXEMPT_PATHS = frozenset({"/"})
# Checked here, before the body is read: a sync body can be 25 MB.
_ROUTE_RULES = {("POST", "/sync"): ("sync", SYNC_USER)}


class RateLimiter:
    """GCRA: one timestamp per key, so the table stays small."""

    def __init__(self, max_keys: int = 100_000):
        self._tat: dict[str, float] = {}
        self._lock = threading.Lock()
        self._max_keys = max_keys
        self._writes = 0

    def _wait(self, key: str, rule: Rule, now: float) -> tuple[float, float]:
        tat = max(self._tat.get(key, now), now)
        new_tat = tat + rule.interval
        return new_tat - rule.period - now, new_tat

    def hit(self, key: str, rule: Rule) -> float:
        """Count one request. 0 when allowed, else seconds until it would be."""
        now = time.monotonic()
        with self._lock:
            wait, new_tat = self._wait(key, rule, now)
            if wait > 0:
                return wait
            self._tat[key] = new_tat
            self._prune(now)
            return 0.0

    def check(self, key: str, rule: Rule) -> float:
        """Like ``hit`` without counting."""
        now = time.monotonic()
        with self._lock:
            wait, _ = self._wait(key, rule, now)
            return max(wait, 0.0)

    def reset(self, key: str) -> None:
        """Forget [key]'s count."""
        with self._lock:
            self._tat.pop(key, None)

    def clear(self) -> None:
        """Forget every count."""
        with self._lock:
            self._tat.clear()

    def _prune(self, now: float) -> None:
        self._writes += 1
        if self._writes % 1000 and len(self._tat) <= self._max_keys:
            return
        for key in [key for key, tat in self._tat.items() if tat <= now]:
            del self._tat[key]
        if len(self._tat) > self._max_keys:
            # A flood of new keys: keep the half closest to their limits.
            busiest = sorted(self._tat.items(), key=lambda item: item[1], reverse=True)
            self._tat = dict(busiest[: self._max_keys // 2])


limiter = RateLimiter()


def _retry_after(wait: float) -> str:
    return str(max(1, math.ceil(wait)))


def too_many(wait: float) -> HTTPException:
    """A 429 with a Retry-After header."""
    return HTTPException(
        status_code=429,
        detail=TOO_MANY,
        headers={"Retry-After": _retry_after(wait)},
    )


def enforce(request: Request, key: str, rule: Rule) -> None:
    """Count this request against [key]; 429 when over the limit."""
    wait = limiter.hit(key, rule)
    if wait > 0:
        log_event("rate_limited", request=request, level=logging.WARNING, key=key.split(":")[0])
        raise too_many(wait)


def enforce_ip(request: Request, name: str, rule: Rule) -> None:
    """``enforce`` keyed by the caller's IP address."""
    enforce(request, f"{name}:ip:{client_ip(request.scope)}", rule)


def email_key(name: str, email: str) -> str:
    """Limiter key for [email], hashed like the logs."""
    return f"{name}:email:{email_tag(email)}"


def bearer_user(scope) -> int | None:
    """The account id in a valid bearer token, without touching the database."""
    for key, value in scope.get("headers") or ():
        if key.lower() != b"authorization":
            continue
        scheme, _, token = value.decode("latin-1").partition(" ")
        if scheme.lower() != "bearer" or not token:
            return None
        decoded = decode_token(token.strip())
        return None if decoded is None else decoded[0]
    return None


class RateLimitMiddleware:
    """The global limit for every HTTP request."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope.get("path") in _EXEMPT_PATHS:
            await self.app(scope, receive, send)
            return
        user_id = bearer_user(scope)
        checks = []
        if user_id is not None:
            checks.append(("global", f"global:user:{user_id}", GLOBAL_USER))
            route = _ROUTE_RULES.get((scope.get("method"), scope.get("path")))
            if route is not None:
                name, rule = route
                checks.append((name, f"{name}:user:{user_id}", rule))
        else:
            checks.append(("global", f"global:ip:{client_ip(scope)}", GLOBAL_IP))
        for name, key, rule in checks:
            wait = limiter.hit(key, rule)
            if wait > 0:
                log_event(
                    "rate_limited",
                    level=logging.WARNING,
                    key=name,
                    ip=client_ip(scope),
                    path=scope.get("path"),
                    user_id=user_id,
                )
                response = JSONResponse(
                    {"detail": TOO_MANY},
                    status_code=429,
                    headers={"Retry-After": _retry_after(wait)},
                )
                await response(scope, receive, send)
                return
        await self.app(scope, receive, send)
