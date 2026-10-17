"""/recurring-expenses: scheduled expenses with an interval and a next due date."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from api_schemas import (
    RecurringExpenseCreate,
    RecurringExpenseOut,
    RecurringExpenseUpdate,
)
from auth import get_current_user
from crud_utils import (
    as_utc_or_now,
    commit_or_existing,
    empty_to_none,
    find_by_client_id,
    normalize_client_id,
    owned_or_404,
    period_from_unit,
    unit_from_period,
    utc_now,
)
from database import get_db
from models import User
from transaction_model import RecurringExpense

router = APIRouter(prefix="/recurring-expenses", tags=["recurring-expenses"])


def _to_out(row: RecurringExpense) -> RecurringExpenseOut:
    return RecurringExpenseOut(
        id=row.id,
        client_id=row.client_id,
        amount=row.amount,
        currency_code=row.currency_code,
        category=row.category,
        payment_method=row.payment_method,
        note=row.note,
        unit=unit_from_period(row.period),
        interval_count=row.interval_count,
        next_due_at=row.next_run_at,
        enabled=row.is_active,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


@router.get("", response_model=list[RecurringExpenseOut])
def list_recurring(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """The user's live recurring expenses, newest first."""
    rows = (
        db.query(RecurringExpense)
        .filter(
            RecurringExpense.user_id == current_user.id,
            RecurringExpense.deleted_at.is_(None),
        )
        .order_by(RecurringExpense.created_at.desc())
        .all()
    )
    return [_to_out(row) for row in rows]


@router.post("", response_model=RecurringExpenseOut, status_code=201)
def create_recurring(
    data: RecurringExpenseCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a recurring expense, or return the one with the same client id."""
    client_id = normalize_client_id(data.client_id)
    existing = find_by_client_id(db, RecurringExpense, current_user.id, client_id)
    if existing is not None:
        return _to_out(existing)

    row = RecurringExpense(
        user_id=current_user.id,
        client_id=client_id,
        amount=data.amount,
        category=data.category,
        payment_method=data.payment_method,
        note=empty_to_none(data.note),
        period=period_from_unit(data.unit),
        interval_count=data.interval_count,
        next_run_at=as_utc_or_now(data.next_due_at),
        is_active=data.enabled,
    )
    db.add(row)
    duplicate = commit_or_existing(db, RecurringExpense, current_user.id, client_id)
    if duplicate is not None:
        return _to_out(duplicate)

    db.refresh(row)
    return _to_out(row)


@router.get("/{expense_id}", response_model=RecurringExpenseOut)
def get_recurring(
    expense_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """One recurring expense, or 404."""
    return _to_out(owned_or_404(db, RecurringExpense, expense_id, current_user.id))


@router.patch("/{expense_id}", response_model=RecurringExpenseOut)
def update_recurring(
    expense_id: int,
    data: RecurringExpenseUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Change the fields sent."""
    row = owned_or_404(db, RecurringExpense, expense_id, current_user.id)
    updates = data.model_dump(exclude_unset=True)

    if "amount" in updates and updates["amount"] is not None:
        row.amount = updates["amount"]
    if "category" in updates and updates["category"] is not None:
        row.category = updates["category"].strip()
    if "payment_method" in updates and updates["payment_method"] is not None:
        row.payment_method = updates["payment_method"]
    if "note" in updates:
        row.note = empty_to_none(updates["note"])
    if "unit" in updates and updates["unit"] is not None:
        row.period = period_from_unit(updates["unit"])
    if "interval_count" in updates and updates["interval_count"] is not None:
        row.interval_count = updates["interval_count"]
    if "next_due_at" in updates:
        row.next_run_at = as_utc_or_now(updates["next_due_at"])
    if "enabled" in updates and updates["enabled"] is not None:
        row.is_active = updates["enabled"]

    db.commit()
    db.refresh(row)
    return _to_out(row)


@router.delete("/{expense_id}", status_code=204)
def delete_recurring(
    expense_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Soft-delete a recurring expense."""
    row = owned_or_404(db, RecurringExpense, expense_id, current_user.id)
    row.deleted_at = utc_now()
    row.updated_at = utc_now()
    db.commit()
    return None
