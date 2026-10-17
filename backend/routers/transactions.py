"""/transactions: income and expense rows, created idempotently by client id."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from api_schemas import TransactionCreate, TransactionOut, TransactionUpdate
from auth import get_current_user
from crud_utils import (
    apply_frequency,
    as_utc_or_now,
    commit_or_existing,
    empty_to_none,
    find_by_client_id,
    normalize_client_id,
    owned_or_404,
    utc_now,
)
from database import get_db
from models import User
from transaction_model import Transaction

router = APIRouter(prefix="/transactions", tags=["transactions"])


def _to_out(row: Transaction) -> TransactionOut:
    return TransactionOut.model_validate(row)


@router.get("", response_model=list[TransactionOut])
def list_transactions(
    type: str | None = Query(default=None, pattern="^(income|expense)$"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """The user's live transactions, newest first, optionally of one type."""
    query = db.query(Transaction).filter(
        Transaction.user_id == current_user.id,
        Transaction.deleted_at.is_(None),
    )
    if type is not None:
        query = query.filter(Transaction.type == type)
    rows = query.order_by(Transaction.occurred_at.desc(), Transaction.id.desc()).all()
    return [_to_out(row) for row in rows]


@router.post("", response_model=TransactionOut, status_code=201)
def create_transaction(
    data: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a transaction, or return the one with the same client or source id."""
    client_id = normalize_client_id(data.client_id)
    # Idempotent: the same client id or source id returns the stored row.
    existing = find_by_client_id(db, Transaction, current_user.id, client_id)
    if existing is not None:
        return _to_out(existing)

    source_id = empty_to_none(data.source_id)
    if source_id is not None:
        by_source = (
            db.query(Transaction)
            .filter(
                Transaction.user_id == current_user.id,
                Transaction.source_id == source_id,
            )
            .first()
        )
        if by_source is not None:
            return _to_out(by_source)

    # New row; a concurrent create with the same ids returns the winner.
    frequency, is_recurring, recurring_period = apply_frequency(data.frequency)

    row = Transaction(
        user_id=current_user.id,
        client_id=client_id,
        type=data.type,
        amount=data.amount,
        category=empty_to_none(data.category),
        payment_method=empty_to_none(data.payment_method),
        note=empty_to_none(data.note),
        source_id=source_id,
        occurred_at=as_utc_or_now(data.occurred_at),
        frequency=frequency,
        period_key=empty_to_none(data.period_key),
        is_recurring=is_recurring,
        recurring_period=recurring_period,
    )
    db.add(row)

    duplicate = commit_or_existing(
        db,
        Transaction,
        current_user.id,
        client_id,
        extra_lookup=lambda: (
            db.query(Transaction)
            .filter(
                Transaction.user_id == current_user.id,
                Transaction.source_id == source_id,
            )
            .first()
            if source_id
            else None
        ),
    )
    if duplicate is not None:
        return _to_out(duplicate)

    db.refresh(row)
    return _to_out(row)


@router.get("/{transaction_id}", response_model=TransactionOut)
def get_transaction(
    transaction_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """One transaction, or 404."""
    row = owned_or_404(db, Transaction, transaction_id, current_user.id)
    return _to_out(row)


@router.patch("/{transaction_id}", response_model=TransactionOut)
def update_transaction(
    transaction_id: int,
    data: TransactionUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Change the fields sent."""
    row = owned_or_404(db, Transaction, transaction_id, current_user.id)
    updates = data.model_dump(exclude_unset=True)

    if "amount" in updates and updates["amount"] is not None:
        row.amount = updates["amount"]
    if "category" in updates:
        row.category = empty_to_none(updates["category"])
    if "payment_method" in updates:
        row.payment_method = empty_to_none(updates["payment_method"])
    if "note" in updates:
        row.note = empty_to_none(updates["note"])
    if "occurred_at" in updates:
        row.occurred_at = as_utc_or_now(updates["occurred_at"])
    if "frequency" in updates and updates["frequency"] is not None:
        frequency, is_recurring, recurring_period = apply_frequency(
            updates["frequency"]
        )
        row.frequency = frequency
        row.is_recurring = is_recurring
        row.recurring_period = recurring_period
    if "period_key" in updates:
        row.period_key = empty_to_none(updates["period_key"])

    db.commit()
    db.refresh(row)
    return _to_out(row)


@router.delete("/{transaction_id}", status_code=204)
def delete_transaction(
    transaction_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Soft-delete a transaction."""
    row = owned_or_404(db, Transaction, transaction_id, current_user.id)
    row.deleted_at = utc_now()
    row.updated_at = utc_now()
    db.commit()
    return None
