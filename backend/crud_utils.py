"""Small helpers shared by the routers: normalizing input, ownership checks,
idempotent creates, and the unit/period and kind/direction mappings.
"""

import re
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from database import new_client_id, utc_now

UNIT_TO_PERIOD = {
    "day": "daily",
    "week": "weekly",
    "month": "monthly",
    "daily": "daily",
    "weekly": "weekly",
    "monthly": "monthly",
}

PERIOD_TO_UNIT = {
    "daily": "day",
    "weekly": "week",
    "monthly": "month",
}

_CURRENCY = re.compile(r"^[A-Z]{3,10}$")


def normalize_currency(value: str | None) -> str:
    """Upper-case currency code, or "SYP" when it is not a valid code."""
    code = (value or "").strip().upper()
    if _CURRENCY.fullmatch(code) is None:
        return "SYP"
    return code


def normalize_enabled_currencies(raw: object) -> list[str]:
    """Unique valid codes, always starting with "SYP"."""
    codes = ["SYP"]
    if not isinstance(raw, list):
        return codes
    for item in raw:
        code = normalize_currency(None if item is None else str(item))
        if code not in codes:
            codes.append(code)
    return codes


def _positive_money(value: object) -> str | None:
    if value is None or value == "":
        return None
    try:
        amount = Decimal(str(value))
    except (InvalidOperation, ValueError):
        return None
    if amount <= 0:
        return None
    return format(amount.quantize(Decimal("0.01")), "f")


def normalize_income_overrides(raw: object) -> dict:
    """Keep positive monthly/weekly amounts per non-SYP currency."""
    if not isinstance(raw, dict):
        return {}
    cleaned: dict[str, dict[str, str]] = {}
    for key, entry in raw.items():
        code = normalize_currency(str(key))
        if code == "SYP" or not isinstance(entry, dict):
            continue
        item: dict[str, str] = {}
        for field in ("monthly", "weekly"):
            amount = _positive_money(entry.get(field))
            if amount is not None:
                item[field] = amount
        if item:
            cleaned[code] = item
    return cleaned


KIND_TO_DIRECTION = {
    "periodLeftover": "to_savings",
    "goalPeriodic": "to_savings",
    "manual": "to_savings",
    "withdraw": "to_balance",
}


def as_utc(value: datetime | None) -> datetime | None:
    """[value] in UTC; a naive value is taken to be UTC already."""
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def as_utc_or_now(value: datetime | None) -> datetime:
    """[value] in UTC, or the current time when it is None."""
    return as_utc(value) or utc_now()


def normalize_client_id(value: str | None) -> str:
    """The trimmed client id, or a new UUID when none was sent."""
    if value is None:
        return new_client_id()
    trimmed = value.strip()
    return trimmed if trimmed else new_client_id()


def empty_to_none(value: str | None) -> str | None:
    """Trimmed text, or None when nothing is left."""
    if value is None:
        return None
    trimmed = value.strip()
    return trimmed if trimmed else None


def is_deleted(record) -> bool:
    """True for a soft-deleted row."""
    return getattr(record, "deleted_at", None) is not None


def not_deleted(model):
    """Query filter for live (not soft-deleted) rows of [model]."""
    return model.deleted_at.is_(None)


def owned_or_404(db: Session, model, record_id: int, user_id: int):
    """The live row [record_id] of [user_id], or a 404."""
    record = db.get(model, record_id)
    if record is None or getattr(record, "user_id", None) != user_id:
        raise HTTPException(status_code=404, detail="Not found")
    if is_deleted(record):
        raise HTTPException(status_code=404, detail="Not found")
    return record


def find_by_client_id(
    db: Session,
    model,
    user_id: int,
    client_id: str | None,
    include_deleted: bool = False,
):
    """The user's row with [client_id], live only unless [include_deleted]."""
    if not client_id:
        return None
    query = db.query(model).filter(
        model.user_id == user_id,
        model.client_id == client_id,
    )
    if not include_deleted and hasattr(model, "deleted_at"):
        query = query.filter(not_deleted(model))
    return query.first()


def soft_delete(record) -> None:
    """Mark [record] deleted now."""
    record.deleted_at = utc_now()
    if hasattr(record, "updated_at"):
        record.updated_at = utc_now()


def commit_or_existing(
    db: Session,
    model,
    user_id: int,
    client_id: str,
    extra_lookup=None,
):
    """Commit a new row; on a unique clash return the row that won.

    Returns None when the commit worked. When another request created the
    same row first, returns that row (found by client id or [extra_lookup]),
    or raises a 400 when there is none.
    """
    try:
        db.commit()
        return None
    except IntegrityError:
        db.rollback()
        existing = find_by_client_id(db, model, user_id, client_id)
        if existing is not None:
            return existing
        if extra_lookup is not None:
            existing = extra_lookup()
            if existing is not None:
                return existing
        raise HTTPException(status_code=400, detail="Could not create record")


def apply_frequency(frequency: str) -> tuple[str, bool, str | None]:
    """(frequency, is_recurring, recurring_period) for a transaction."""
    if frequency in {"weekly", "monthly"}:
        return frequency, True, frequency
    return "none", False, None


def period_from_unit(unit: str) -> str:
    """Stored period (daily, weekly, monthly) for an API unit, or 422."""
    period = UNIT_TO_PERIOD.get(unit)
    if period is None:
        raise HTTPException(status_code=422, detail="Invalid recurrence unit")
    return period


def unit_from_period(period: str) -> str:
    """API unit (day, week, month) for a stored period."""
    return PERIOD_TO_UNIT.get(period, "day")


def direction_from_kind(kind: str | None, direction: str | None) -> str:
    """Transfer direction: as given, else from the kind, else 422."""
    if direction in {"to_savings", "to_balance"}:
        return direction
    if kind in KIND_TO_DIRECTION:
        return KIND_TO_DIRECTION[kind]
    raise HTTPException(
        status_code=422,
        detail="direction or kind is required",
    )
