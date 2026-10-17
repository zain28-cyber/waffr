"""/shopping-lists and their /items. Deleting a list deletes its items."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, selectinload

from api_schemas import (
    ShoppingItemCreate,
    ShoppingItemOut,
    ShoppingItemUpdate,
    ShoppingListCreate,
    ShoppingListOut,
    ShoppingListUpdate,
)
from auth import get_current_user
from crud_utils import (
    as_utc,
    commit_or_existing,
    empty_to_none,
    find_by_client_id,
    normalize_client_id,
    owned_or_404,
    utc_now,
)
from database import get_db
from models import User
from shopping_model import ShoppingItem, ShoppingList

router = APIRouter(prefix="/shopping-lists", tags=["shopping"])


def _list_out(row: ShoppingList) -> ShoppingListOut:
    items = sorted(
        [item for item in row.items if item.deleted_at is None],
        key=lambda item: item.created_at,
        reverse=True,
    )
    return ShoppingListOut(
        id=row.id,
        client_id=row.client_id,
        name=row.name,
        created_at=row.created_at,
        updated_at=row.updated_at,
        items=[ShoppingItemOut.model_validate(item) for item in items],
    )


def _owned_list(db: Session, list_id: int, user_id: int) -> ShoppingList:
    row = (
        db.query(ShoppingList)
        .options(selectinload(ShoppingList.items))
        .filter(
            ShoppingList.id == list_id,
            ShoppingList.user_id == user_id,
            ShoppingList.deleted_at.is_(None),
        )
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Not found")
    return row


def _owned_item(
    db: Session,
    list_id: int,
    item_id: int,
    user_id: int,
) -> ShoppingItem:
    item = (
        db.query(ShoppingItem)
        .filter(
            ShoppingItem.id == item_id,
            ShoppingItem.list_id == list_id,
            ShoppingItem.user_id == user_id,
            ShoppingItem.deleted_at.is_(None),
        )
        .first()
    )
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")
    return item


@router.get("", response_model=list[ShoppingListOut])
def list_lists(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """The user's live lists with their items, most recently changed first."""
    rows = (
        db.query(ShoppingList)
        .options(selectinload(ShoppingList.items))
        .filter(
            ShoppingList.user_id == current_user.id,
            ShoppingList.deleted_at.is_(None),
        )
        .order_by(ShoppingList.updated_at.desc())
        .all()
    )
    return [_list_out(row) for row in rows]


@router.post("", response_model=ShoppingListOut, status_code=201)
def create_list(
    data: ShoppingListCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a list, or return the one with the same client id."""
    client_id = normalize_client_id(data.client_id)
    existing = find_by_client_id(db, ShoppingList, current_user.id, client_id)
    if existing is not None:
        existing = _owned_list(db, existing.id, current_user.id)
        return _list_out(existing)

    row = ShoppingList(
        user_id=current_user.id,
        client_id=client_id,
        name=data.name,
    )
    db.add(row)
    duplicate = commit_or_existing(db, ShoppingList, current_user.id, client_id)
    if duplicate is not None:
        duplicate = _owned_list(db, duplicate.id, current_user.id)
        return _list_out(duplicate)

    db.refresh(row)
    row.items = []
    return _list_out(row)


@router.get("/{list_id}", response_model=ShoppingListOut)
def get_list(
    list_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """One list with its items, or 404."""
    return _list_out(_owned_list(db, list_id, current_user.id))


@router.patch("/{list_id}", response_model=ShoppingListOut)
def update_list(
    list_id: int,
    data: ShoppingListUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Rename a list."""
    row = _owned_list(db, list_id, current_user.id)
    if data.name is not None:
        row.name = data.name
    db.commit()
    db.refresh(row)
    return _list_out(_owned_list(db, list_id, current_user.id))


@router.delete("/{list_id}", status_code=204)
def delete_list(
    list_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Soft-delete a list and its items."""
    row = owned_or_404(db, ShoppingList, list_id, current_user.id)
    now = utc_now()
    row.deleted_at = now
    row.updated_at = now
    for item in row.items:
        if item.deleted_at is None:
            item.deleted_at = now
            item.updated_at = now
    db.commit()
    return None


@router.get("/{list_id}/items", response_model=list[ShoppingItemOut])
def list_items(
    list_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """A list's live items, newest first."""
    shopping_list = _owned_list(db, list_id, current_user.id)
    items = sorted(
        [item for item in shopping_list.items if item.deleted_at is None],
        key=lambda item: item.created_at,
        reverse=True,
    )
    return [ShoppingItemOut.model_validate(item) for item in items]


@router.post("/{list_id}/items", response_model=ShoppingItemOut, status_code=201)
def create_item(
    list_id: int,
    data: ShoppingItemCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Add an item; 409 when its client id is already used in another list."""
    _owned_list(db, list_id, current_user.id)
    client_id = normalize_client_id(data.client_id)
    existing = find_by_client_id(db, ShoppingItem, current_user.id, client_id)
    if existing is not None:
        if existing.list_id != list_id:
            raise HTTPException(status_code=409, detail="client_id already exists")
        return ShoppingItemOut.model_validate(existing)

    row = ShoppingItem(
        user_id=current_user.id,
        list_id=list_id,
        client_id=client_id,
        name=data.name,
        quantity=data.quantity,
        price=data.price,
        is_purchased=data.is_purchased,
        purchased_at=as_utc(data.purchased_at),
        expense_client_id=empty_to_none(data.expense_client_id),
    )
    db.add(row)
    duplicate = commit_or_existing(db, ShoppingItem, current_user.id, client_id)
    if duplicate is not None:
        return ShoppingItemOut.model_validate(duplicate)

    db.refresh(row)
    return ShoppingItemOut.model_validate(row)


@router.get("/{list_id}/items/{item_id}", response_model=ShoppingItemOut)
def get_item(
    list_id: int,
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """One item of the list, or 404."""
    return ShoppingItemOut.model_validate(
        _owned_item(db, list_id, item_id, current_user.id)
    )


@router.patch("/{list_id}/items/{item_id}", response_model=ShoppingItemOut)
def update_item(
    list_id: int,
    item_id: int,
    data: ShoppingItemUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Change the fields sent; unpurchasing clears the purchase details."""
    row = _owned_item(db, list_id, item_id, current_user.id)
    updates = data.model_dump(exclude_unset=True)

    if "name" in updates and updates["name"] is not None:
        row.name = updates["name"]
    if "quantity" in updates and updates["quantity"] is not None:
        row.quantity = updates["quantity"]
    if "price" in updates:
        row.price = updates["price"]
    if "is_purchased" in updates and updates["is_purchased"] is not None:
        row.is_purchased = updates["is_purchased"]
        if not row.is_purchased:
            row.purchased_at = None
            row.expense_client_id = None
    if "purchased_at" in updates:
        row.purchased_at = as_utc(updates["purchased_at"])
    if "expense_client_id" in updates:
        row.expense_client_id = empty_to_none(updates["expense_client_id"])

    db.commit()
    db.refresh(row)
    return ShoppingItemOut.model_validate(row)


@router.delete("/{list_id}/items/{item_id}", status_code=204)
def delete_item(
    list_id: int,
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Soft-delete an item."""
    row = _owned_item(db, list_id, item_id, current_user.id)
    row.deleted_at = utc_now()
    row.updated_at = utc_now()
    db.commit()
    return None
