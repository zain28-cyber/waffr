"""HTTP hardening: security headers, request size limits, CORS, API docs."""

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse

from rate_limit import RateLimitMiddleware, bearer_user

# A first sync uploads the whole ledger in one request; nothing else is big.
DEFAULT_MAX_BODY_BYTES = 256 * 1024
SYNC_MAX_BODY_BYTES = 25 * 1024 * 1024

_DOCS_PATHS = ("/docs", "/redoc")

_SECURITY_HEADERS = (
    # Render serves HTTPS only; browsers should never try plain HTTP.
    (b"strict-transport-security", b"max-age=63072000; includeSubDomains"),
    (b"x-content-type-options", b"nosniff"),
    (b"x-frame-options", b"DENY"),
    (b"referrer-policy", b"no-referrer"),
    (b"cross-origin-resource-policy", b"same-origin"),
    # Responses carry private financial data; no cache should keep them.
    (b"cache-control", b"no-store"),
)
_CSP = (b"content-security-policy", b"default-src 'none'; frame-ancestors 'none'")


def _flag(name: str) -> bool:
    return (os.getenv(name) or "").strip().lower() in {"1", "true", "yes"}


def docs_settings() -> dict:
    """FastAPI's /docs, /redoc and /openapi.json stay off unless asked for."""
    if _flag("ENABLE_API_DOCS"):
        return {}
    return {"docs_url": None, "redoc_url": None, "openapi_url": None}


def _cors_origins() -> list[str]:
    raw = os.getenv("CORS_ORIGINS") or ""
    return [origin.strip() for origin in raw.split(",") if origin.strip()]


def max_body_bytes(scope) -> int:
    """Largest body allowed for this request."""
    # Only a signed-in sync gets the big allowance; anyone else's body is
    # refused before it is read and parsed.
    if scope.get("path") == "/sync" and bearer_user(scope) is not None:
        return SYNC_MAX_BODY_BYTES
    return DEFAULT_MAX_BODY_BYTES


class SecurityHeadersMiddleware:
    """Adds the security headers to every response."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        path = scope.get("path") or ""
        extra = list(_SECURITY_HEADERS)
        # Swagger UI loads its own scripts; it only exists with ENABLE_API_DOCS.
        if not path.startswith(_DOCS_PATHS):
            extra.append(_CSP)

        async def send_with_headers(message):
            if message["type"] == "http.response.start":
                headers = list(message.get("headers") or [])
                present = {key.lower() for key, _ in headers}
                headers.extend(item for item in extra if item[0] not in present)
                message = {**message, "headers": headers}
            await send(message)

        await self.app(scope, receive, send_with_headers)


class BodySizeLimitMiddleware:
    """413 for bodies over the limit, before the app reads them."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        limit = max_body_bytes(scope)
        declared = None
        for key, value in scope.get("headers") or ():
            if key.lower() == b"content-length":
                declared = value
                break

        if declared is not None:
            try:
                length = int(declared)
            except ValueError:
                await _error(scope, receive, send, 400, "Invalid Content-Length")
                return
            if length > limit:
                await _error(scope, receive, send, 413, "Request body too large")
                return
            # The server enforces Content-Length framing, so the body cannot
            # run past the declared size.
            await self.app(scope, receive, send)
            return

        # No length (chunked upload): read up to the limit, then replay it.
        body = bytearray()
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            body.extend(message.get("body", b""))
            if len(body) > limit:
                await _error(scope, receive, send, 413, "Request body too large")
                return
            if not message.get("more_body", False):
                break

        replayed = False

        async def replay():
            nonlocal replayed
            if replayed:
                return await receive()
            replayed = True
            return {"type": "http.request", "body": bytes(body), "more_body": False}

        await self.app(scope, replay, send)


async def _error(scope, receive, send, status: int, detail: str) -> None:
    await JSONResponse({"detail": detail}, status_code=status)(scope, receive, send)


def install(app: FastAPI) -> None:
    """Add the middleware stack to [app]."""
    # Added inside-out: the last one added sees the request first.
    app.add_middleware(BodySizeLimitMiddleware)
    app.add_middleware(RateLimitMiddleware)
    origins = _cors_origins()
    if origins:
        # The phone app needs no CORS. Set CORS_ORIGINS only for a web build;
        # tokens travel in the Authorization header, never in cookies.
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
            allow_headers=["Authorization", "Content-Type"],
            allow_credentials=False,
            max_age=600,
        )
    app.add_middleware(SecurityHeadersMiddleware)
