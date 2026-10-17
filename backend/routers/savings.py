"""/savings-goals and /savings-transfers: goals and the money moved into them.

A goal's saved amount is derived from its live transfers on every read.
"""

from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from api_schemas import (
    SavingsGoalCreate,
    SavingsGoalOut,
    SavingsGoalUpdate,
    SavingsTransferCreate,
    SavingsTransferOut,
)
from auth import get_current_user
from crud_utils import (
    as_utc,
    as_utc_or_now,
    commit_or_existing,
    direction_from_kind,
    empty_to_none,
    find_by_client_id,
    normalize_client_id,
    owned_or_404,
    utc_now,
)
from database import get_db
from goal_model import SavingsGoal, SavingsTransfer
from models import User

router = APIRouter(tags=["savings"])


def _saved_amount(goal: SavingsGoal, transfers: list[SavingsTransfer]) -> Decimal:
    if goal.completed_at is not None and goal.completed_amount is not None:
        return goal.completed_amount

    saved = Decimal("0.00")
    withdrawn = Decimal("0.00")
    for item in transfers:
        if item.goal_id != goal.id:
            continue
        if item.direction == "to_savings":
            saved += item.amount
        elif item.direction == "to_balance":
            withdrawn += item.amount

    progress = saved - withdrawn
    return progress if progress > 0 else Decimal("0.00")


def _goal_out(goal: SavingsGoal, transfers: list[SavingsTransfer]) -> SavingsGoalOut:
    completed = goal.completed_at is not None
    return SavingsGoalOut(
        id=goal.id,
        client_id=goal.client_id,
        name=goal.name,
        currency_code=goal.currency_code,
        target_amount=goal.target_amount,
        saved_amount=_saved_amount(goal, transfers),
        duration=goal.duration,
        deadline=goal.deadline,
        allocate_percent=goal.allocate_percent,
        allocate_amount=goal.allocate_amount,
        deduct_frequency=goal.deduct_frequency,
        is_periodic=goal.is_periodic,
        duration_count=goal.duration_count,
        priority=goal.priority,
        completed_at=goal.completed_at,
        completed_amount=goal.completed_amount,
        is_completed=completed or goal.is_completed,
        created_at=goal.created_at,
        updated_at=goal.updated_at,
    )


def _user_transfers(db: Session, user_id: int) -> list[SavingsTransfer]:
    return (
        db.query(SavingsTransfer)
        .filter(
            SavingsTransfer.user_id == user_id,
            SavingsTransfer.deleted_at.is_(None),
        )
        .all()
    )


def _resolve_goal(
    db: Session,
    user_id: int,
    goal_id: int | None,
    goal_client_id: str | None,
) -> SavingsGoal | None:
    if goal_id is not None:
        return owned_or_404(db, SavingsGoal, goal_id, user_id)
    client_id = empty_to_none(goal_client_id)
    if client_id is None:
        return None
    goal = find_by_client_id(db, SavingsGoal, user_id, client_id)
    if goal is None:
        raise HTTPException(status_code=404, detail="Savings goal not found")
    return goal


@router.get("/savings-goals", response_model=list[SavingsGoalOut])
def list_goals(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """The user's live goals by priority, with saved amounts."""
    goals = (
        db.query(SavingsGoal)
        .filter(
            SavingsGoal.user_id == current_user.id,
            SavingsGoal.deleted_at.is_(None),
        )
        .order_by(SavingsGoal.priority.asc(), SavingsGoal.id.asc())
        .all()
    )
    transfers = _user_transfers(db, current_user.id)
    return [_goal_out(goal, transfers) for goal in goals]


@router.post("/savings-goals", response_model=SavingsGoalOut, status_code=201)
def create_goal(
    data: SavingsGoalCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a goal, or return the one with the same client id.

    Periodic goals need an amount, a deduct frequency and a duration count.
    """
    client_id = normalize_client_id(data.client_id)
    existing = find_by_client_id(db, SavingsGoal, current_user.id, client_id)
    if existing is not None:
        return _goal_out(existing, _user_transfers(db, current_user.id))

    # A periodic goal needs a complete deduction plan.
    if data.is_periodic:
        if data.allocate_amount is None or data.allocate_amount <= 0:
            raise HTTPException(
                status_code=422,
                detail="Periodic goals require allocate_amount",
            )
        if data.deduct_frequency == "none":
            raise HTTPException(
                status_code=422,
                detail="Periodic goals require a deduct frequency",
            )
        if data.duration_count is None:
            raise HTTPException(
                status_code=422,
                detail="Periodic goals require duration_count",
            )

    # New goals go last unless a priority is given.
    count = (
        db.query(SavingsGoal)
        .filter(
            SavingsGoal.user_id == current_user.id,
            SavingsGoal.deleted_at.is_(None),
        )
        .count()
    )
    completed_at = as_utc(data.completed_at)

    row = SavingsGoal(
        user_id=current_user.id,
        client_id=client_id,
        name=data.name,
        target_amount=data.target_amount,
        duration=data.duration,
        deadline=as_utc(data.deadline),
        allocate_percent=data.allocate_percent,
        allocate_amount=data.allocate_amount if data.is_periodic else None,
        deduct_frequency=data.deduct_frequency,
        is_periodic=data.is_periodic,
        duration_count=data.duration_count,
        priority=count if data.priority is None else data.priority,
        completed_at=completed_at,
        completed_amount=data.completed_amount,
        is_completed=completed_at is not None,
    )
    db.add(row)
    duplicate = commit_or_existing(db, SavingsGoal, current_user.id, client_id)
    if duplicate is not None:
        return _goal_out(duplicate, _user_transfers(db, current_user.id))

    db.refresh(row)
    return _goal_out(row, [])


@router.get("/savings-goals/{goal_id}", response_model=SavingsGoalOut)
def get_goal(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """One goal with its saved amount, or 404."""
    row = owned_or_404(db, SavingsGoal, goal_id, current_user.id)
    return _goal_out(row, _user_transfers(db, current_user.id))


@router.patch("/savings-goals/{goal_id}", response_model=SavingsGoalOut)
def update_goal(
    goal_id: int,
    data: SavingsGoalUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Change the fields sent; is_completed also sets or clears completion."""
    row = owned_or_404(db, SavingsGoal, goal_id, current_user.id)
    updates = data.model_dump(exclude_unset=True)

    for field in (
        "name",
        "target_amount",
        "duration",
        "allocate_percent",
        "allocate_amount",
        "deduct_frequency",
        "is_periodic",
        "duration_count",
        "priority",
        "completed_amount",
    ):
        if field in updates:
            setattr(row, field, updates[field])

    if "deadline" in updates:
        row.deadline = as_utc(updates["deadline"])

    if "completed_at" in updates:
        row.completed_at = as_utc(updates["completed_at"])
        row.is_completed = row.completed_at is not None

    if "is_completed" in updates:
        if updates["is_completed"]:
            row.is_completed = True
            if row.completed_at is None:
                row.completed_at = utc_now()
        else:
            row.is_completed = False
            row.completed_at = None
            row.completed_amount = None

    db.commit()
    db.refresh(row)
    return _goal_out(row, _user_transfers(db, current_user.id))


@router.delete("/savings-goals/{goal_id}", status_code=204)
def delete_goal(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Soft-delete a goal. Its transfers stay."""
    row = owned_or_404(db, SavingsGoal, goal_id, current_user.id)
    row.deleted_at = utc_now()
    row.updated_at = utc_now()
    db.commit()
    return None


@router.get("/savings-transfers", response_model=list[SavingsTransferOut])
def list_transfers(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """The user's live transfers, newest first."""
    rows = (
        db.query(SavingsTransfer)
        .filter(
            SavingsTransfer.user_id == current_user.id,
            SavingsTransfer.deleted_at.is_(None),
        )
        .order_by(SavingsTransfer.occurred_at.desc(), SavingsTransfer.id.desc())
        .all()
    )
    return [SavingsTransferOut.model_validate(row) for row in rows]


@router.post("/savings-transfers", response_model=SavingsTransferOut, status_code=201)
def create_transfer(
    data: SavingsTransferCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a transfer, or return the one with the same client id."""
    client_id = normalize_client_id(data.client_id)
    existing = find_by_client_id(db, SavingsTransfer, current_user.id, client_id)
    if existing is not None:
        return SavingsTransferOut.model_validate(existing)

    goal = _resolve_goal(db, current_user.id, data.goal_id, data.goal_client_id)
    direction = direction_from_kind(data.kind, data.direction)

    row = SavingsTransfer(
        user_id=current_user.id,
        client_id=client_id,
        goal_id=None if goal is None else goal.id,
        amount=data.amount,
        direction=direction,
        kind=data.kind,
        note=empty_to_none(data.note),
        occurred_at=as_utc_or_now(data.occurred_at),
        processed_period_key=empty_to_none(data.processed_period_key),
    )
    db.add(row)
    duplicate = commit_or_existing(db, SavingsTransfer, current_user.id, client_id)
    if duplicate is not None:
        return SavingsTransferOut.model_validate(duplicate)

    db.refresh(row)
    return SavingsTransferOut.model_validate(row)


@router.get("/savings-transfers/{transfer_id}", response_model=SavingsTransferOut)
def get_transfer(
    transfer_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """One transfer, or 404."""
    row = owned_or_404(db, SavingsTransfer, transfer_id, current_user.id)
    return SavingsTransferOut.model_validate(row)


@router.delete("/savings-transfers/{transfer_id}", status_code=204)
def delete_transfer(
    transfer_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Soft-delete a transfer."""
    row = owned_or_404(db, SavingsTransfer, transfer_id, current_user.id)
    row.deleted_at = utc_now()
    row.updated_at = utc_now()
    db.commit()
    return None
