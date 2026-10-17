"""/notifications: in-app notifications, at most one live row per event key."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from api_schemas import NotificationCreate, NotificationOut, NotificationUpdate
from auth import get_current_user
from crud_utils import (
    as_utc_or_now,
    commit_or_existing,
    empty_to_none,
    find_by_client_id,
    normalize_client_id,
    owned_or_404,
    utc_now,
)
from database import get_db
from models import Notification, User

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _to_out(row: Notification) -> NotificationOut:
    raw = row.event_metadata or {}
    metadata = {str(key): str(value) for key, value in raw.items()}
    return NotificationOut(
        id=row.id,
        client_id=row.client_id,
        type=row.type,
        title=row.title,
        message=row.message,
        is_read=row.is_read,
        event_key=row.event_key,
        related_id=row.related_id,
        metadata=metadata,
        created_at=row.created_at,
    )


@router.get("", response_model=list[NotificationOut])
def list_notifications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """The user's live notifications, newest first."""
    rows = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.deleted_at.is_(None),
        )
        .order_by(Notification.created_at.desc(), Notification.id.desc())
        .all()
    )
    return [_to_out(row) for row in rows]


@router.post("", response_model=NotificationOut, status_code=201)
def create_notification(
    data: NotificationCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a notification, or return the one with the same client id or event key."""
    client_id = normalize_client_id(data.client_id)
    existing = find_by_client_id(db, Notification, current_user.id, client_id)
    if existing is not None:
        return _to_out(existing)

    by_event = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.event_key == data.event_key.strip(),
        )
        .first()
    )
    if by_event is not None:
        return _to_out(by_event)

    row = Notification(
        user_id=current_user.id,
        client_id=client_id,
        type=data.type.strip(),
        title=data.title.strip(),
        message=data.message.strip(),
        is_read=data.is_read,
        event_key=data.event_key.strip(),
        related_id=empty_to_none(data.related_id),
        event_metadata=data.metadata,
        created_at=as_utc_or_now(data.created_at),
    )
    db.add(row)
    duplicate = commit_or_existing(
        db,
        Notification,
        current_user.id,
        client_id,
        extra_lookup=lambda: (
            db.query(Notification)
            .filter(
                Notification.user_id == current_user.id,
                Notification.event_key == data.event_key.strip(),
            )
            .first()
        ),
    )
    if duplicate is not None:
        return _to_out(duplicate)

    db.refresh(row)
    return _to_out(row)


@router.post("/mark-all-read", response_model=list[NotificationOut])
def mark_all_read(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Mark every live notification read and return them."""
    rows = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.deleted_at.is_(None),
        )
        .all()
    )
    for row in rows:
        row.is_read = True
    db.commit()
    return list_notifications(current_user=current_user, db=db)


@router.get("/{notification_id}", response_model=NotificationOut)
def get_notification(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """One notification, or 404."""
    return _to_out(owned_or_404(db, Notification, notification_id, current_user.id))


@router.patch("/{notification_id}", response_model=NotificationOut)
def update_notification(
    notification_id: int,
    data: NotificationUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Change a notification's read state."""
    row = owned_or_404(db, Notification, notification_id, current_user.id)
    if data.is_read is not None:
        row.is_read = data.is_read
    db.commit()
    db.refresh(row)
    return _to_out(row)


@router.delete("/{notification_id}", status_code=204)
def delete_notification(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Soft-delete one notification."""
    row = owned_or_404(db, Notification, notification_id, current_user.id)
    row.deleted_at = utc_now()
    row.updated_at = utc_now()
    db.commit()
    return None


@router.delete("", status_code=204)
def clear_notifications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Soft-delete every live notification."""
    now = utc_now()
    rows = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.deleted_at.is_(None),
        )
        .all()
    )
    for row in rows:
        row.deleted_at = now
        row.updated_at = now
    db.commit()
    return None
