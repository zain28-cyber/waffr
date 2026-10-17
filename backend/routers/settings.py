"""/settings: read and change the user's settings row (shared with /sync)."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from api_schemas import UserSettingsOut, UserSettingsUpdate
from auth import get_current_user
from database import get_db
from models import User, UserSettings

router = APIRouter(prefix="/settings", tags=["settings"])


def _get_or_create(db: Session, user: User) -> UserSettings:
    if user.settings is not None:
        return user.settings

    existing = (
        db.query(UserSettings).filter(UserSettings.user_id == user.id).first()
    )
    if existing is not None:
        return existing

    settings = UserSettings(user_id=user.id)
    db.add(settings)
    db.commit()
    db.refresh(settings)
    return settings


def _to_out(row: UserSettings) -> UserSettingsOut:
    return UserSettingsOut(
        notifications_enabled=row.notifications_enabled,
        notifications_muted=not row.notifications_enabled,
        notify_low_balance=row.notify_low_balance,
        notify_spending_threshold=row.notify_spending_threshold,
        notify_goal_reached=row.notify_goal_reached,
        notify_recurring_expense=row.notify_recurring_expense,
        ai_data_enabled=row.ai_data_enabled,
        monthly_income_amount=row.monthly_income_amount,
        weekly_income_amount=row.weekly_income_amount,
        income_overrides_by_currency=dict(row.income_overrides_by_currency or {}),
        enabled_currencies=list(row.enabled_currencies or ["SYP"]),
        active_currency=row.active_currency or "SYP",
        processed_period_keys=list(row.processed_period_keys or []),
        updated_at=row.updated_at,
    )


@router.get("", response_model=UserSettingsOut)
def get_settings(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """The user's settings, created with defaults when missing."""
    return _to_out(_get_or_create(db, current_user))


@router.patch("", response_model=UserSettingsOut)
def update_settings(
    data: UserSettingsUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Change the fields sent. processed_period_keys is replaced, not merged."""
    row = _get_or_create(db, current_user)
    updates = data.model_dump(exclude_unset=True)

    if "notifications_muted" in updates and updates["notifications_muted"] is not None:
        row.notifications_enabled = not updates["notifications_muted"]
    if "notifications_enabled" in updates and updates["notifications_enabled"] is not None:
        row.notifications_enabled = updates["notifications_enabled"]

    for field in (
        "notify_low_balance",
        "notify_spending_threshold",
        "notify_goal_reached",
        "notify_recurring_expense",
        "ai_data_enabled",
        "monthly_income_amount",
        "weekly_income_amount",
        "processed_period_keys",
    ):
        if field in updates:
            setattr(row, field, updates[field])

    db.commit()
    db.refresh(row)
    return _to_out(row)
