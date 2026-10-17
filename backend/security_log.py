"""Security events: one JSON line each on the "waffr.security" logger.

Render keeps the service's stdout, so these show up in its Logs tab. Emails
are logged as a keyed hash, never in the clear; passwords, codes and tokens
are never logged.
"""

import hashlib
import hmac
import json
import logging

from auth import SECRET_KEY
from client_address import client_ip

logger = logging.getLogger("waffr.security")

_TAG_KEY = hashlib.sha256(b"waffr-log-tag:" + SECRET_KEY.encode()).digest()


def email_tag(email: str) -> str:
    """Same email, same tag, so repeated attempts can be grouped."""
    normalized = email.strip().lower().encode()
    return hmac.new(_TAG_KEY, normalized, hashlib.sha256).hexdigest()[:16]


def log_event(
    event: str,
    *,
    request=None,
    level: int = logging.INFO,
    user_id: int | None = None,
    email: str | None = None,
    **fields,
) -> None:
    """Log one security event as a JSON line, with the request's address."""
    record: dict = {"event": event}
    if request is not None:
        record["ip"] = client_ip(request.scope)
        record["method"] = request.method
        record["path"] = request.url.path
    if user_id is not None:
        record["user_id"] = user_id
    if email:
        record["email"] = email_tag(email)
    record.update(fields)
    logger.log(level, json.dumps(record, ensure_ascii=False, default=str))


def configure_logging() -> None:
    """Uvicorn sets up only its own loggers; give ours a handler too."""
    root = logging.getLogger("waffr")
    if root.handlers:
        return
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(levelname)s %(name)s %(message)s"))
    root.addHandler(handler)
    root.setLevel(logging.INFO)
    root.propagate = False
