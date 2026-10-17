"""POST /sync: two-way sync of every collection and the settings object.

The app pushes rows changed since its last sync and tombstones for rows it
deleted; the reply holds every row changed on the server since
``last_sync_at``, plus the full settings. Rows match by (user, client_id)
and the newer ``updated_at`` wins. See backend/README.md for the rules.
"""

import logging
import re
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session
from sqlalchemy.orm.attributes import flag_modified

from auth import get_current_user
from crud_utils import (
    apply_frequency,
    as_utc,
    as_utc_or_now,
    direction_from_kind,
    empty_to_none,
    normalize_currency,
    normalize_enabled_currencies,
    normalize_income_overrides,
    period_from_unit,
    unit_from_period,
    utc_now,
)
from database import get_db, scrub_private_text
from legacy_photo import photo_meta
from category_model import ExpenseCategory
from goal_model import SavingsGoal, SavingsTransfer
from models import Notification, User, UserSettings
from preset_model import ExpensePreset
from shopping_model import ShoppingItem, ShoppingList
from sync_schemas import (
    CategorySyncIn,
    GoalSyncIn,
    NotificationSyncIn,
    PresetSyncIn,
    RecurringSyncIn,
    SettingsSyncIn,
    SettingsSyncOut,
    ShoppingItemSyncIn,
    ShoppingListSyncIn,
    SyncCollectionOut,
    SyncRequest,
    SyncResponse,
    TombstoneIn,
    TransactionSyncIn,
    TransferSyncIn,
)
from transaction_model import RecurringExpense, Transaction

router = APIRouter(tags=["sync"])
logger = logging.getLogger("waffr.sync")


def _newer_or_equal(incoming: datetime | None, current: datetime | None) -> bool:
    if incoming is None:
        return current is None
    if current is None:
        return True
    incoming_utc = as_utc(incoming)
    current_utc = as_utc(current)
    return incoming_utc >= current_utc


def _parse_many(model, items: list[dict]):
    parsed = []
    for item in items:
        try:
            parsed.append(model.model_validate(item))
        except Exception as error:
            raise HTTPException(status_code=422, detail=str(error)) from error
    return parsed


def _get_by_client(db: Session, model, user_id: int, client_id: str):
    db.flush()
    return (
        db.query(model)
        .filter(model.user_id == user_id, model.client_id == client_id)
        .first()
    )


def _apply_delete(row, deleted_at: datetime | None) -> None:
    stamp = as_utc_or_now(deleted_at)
    if row.deleted_at is not None and not _newer_or_equal(stamp, row.deleted_at):
        return
    if hasattr(row, "updated_at") and not _newer_or_equal(stamp, row.updated_at):
        return
    row.deleted_at = stamp
    if hasattr(row, "updated_at"):
        row.updated_at = stamp
    scrub_private_text(row)


def _changed_since(query, model, last_sync: datetime | None):
    if last_sync is None:
        return query
    filters = [model.updated_at > last_sync]
    if hasattr(model, "deleted_at"):
        filters.append(model.deleted_at > last_sync)
    return query.filter(or_(*filters))


def _settings_row(db: Session, user: User) -> tuple[UserSettings, bool]:
    existing = db.query(UserSettings).filter(UserSettings.user_id == user.id).first()
    if existing is not None:
        return existing, False
    row = UserSettings(user_id=user.id, processed_period_keys=[])
    db.add(row)
    db.flush()
    return row, True


def _keep_event_time(current: datetime | None, incoming: datetime | None) -> datetime:
    """Keep the client's event time. Server receipt time is not a substitute."""
    parsed = as_utc(incoming)
    if parsed is not None:
        return parsed
    if current is not None:
        return current
    return utc_now()


def _apply_settings(
    row: UserSettings,
    user: User,
    data: SettingsSyncIn,
    *,
    created: bool = False,
) -> None:
    incoming = as_utc(data.updated_at)
    # The streak merges by calendar day, not by the settings timestamp, so a
    # device whose other settings are older still records today's open.
    _merge_streak(row, data)
    if (
        not created
        and incoming is not None
        and not _newer_or_equal(incoming, row.updated_at)
    ):
        keys = set(row.processed_period_keys or [])
        keys.update(data.processed_period_keys or [])
        row.processed_period_keys = sorted(keys)
        # Write the stored stamp back as it is. Otherwise the column's
        # onupdate moves it to the server's clock whenever the keys or the
        # streak changed, and a newer edit pushed later looks stale.
        flag_modified(row, "updated_at")
        return

    if data.notifications_muted is not None:
        row.notifications_enabled = not data.notifications_muted
    if data.notifications_enabled is not None:
        row.notifications_enabled = data.notifications_enabled
    for field in (
        "notify_low_balance",
        "notify_spending_threshold",
        "notify_goal_reached",
        "notify_recurring_expense",
        "ai_data_enabled",
        "dark_mode",
    ):
        value = getattr(data, field)
        if value is not None:
            setattr(row, field, value)
    for field in ("gender", "birthdate"):
        value = getattr(data, field)
        if value is None:
            continue
        cleaned = value.strip() or None
        setattr(row, field, cleaned)
        setattr(user, field, cleaned)
    for field in ("country", "city", "street", "phone"):
        value = getattr(data, field)
        if value is None:
            continue
        setattr(user, field, value.strip() or None)
    if data.hidden_categories is not None:
        row.hidden_categories = _clean_labels(data.hidden_categories)
    # Null is meaningful: the user removed the configured income.
    for field in ("monthly_income_amount", "weekly_income_amount"):
        if field in data.model_fields_set:
            setattr(row, field, getattr(data, field))
    if "income_overrides_by_currency" in data.model_fields_set:
        row.income_overrides_by_currency = normalize_income_overrides(
            data.income_overrides_by_currency
        )
    if "enabled_currencies" in data.model_fields_set:
        row.enabled_currencies = normalize_enabled_currencies(data.enabled_currencies)
    if "active_currency" in data.model_fields_set:
        active = normalize_currency(data.active_currency)
        enabled = list(row.enabled_currencies or ["SYP"])
        row.active_currency = active if active in enabled else "SYP"
    if data.display_name is not None:
        name = data.display_name.strip()
        user.name = name or None
    keys = set(row.processed_period_keys or [])
    keys.update(data.processed_period_keys or [])
    row.processed_period_keys = sorted(keys)
    if incoming is not None:
        row.updated_at = incoming


_DAY_KEY_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def _merge_streak(row: UserSettings, data: SettingsSyncIn) -> None:
    """Keep the streak with the later last day; same day keeps the longer one.

    ``usage_started_at`` keeps the earliest value seen. Mirrors
    ``StreakMath.merge`` in the app.
    """
    started = (data.usage_started_at or "").strip()
    if started:
        current = (row.usage_started_at or "").strip()
        parsed = as_utc(_parse_iso(started))
        if not current:
            row.usage_started_at = started
        elif parsed is not None:
            existing = as_utc(_parse_iso(current))
            if existing is None or parsed < existing:
                row.usage_started_at = started

    day = (data.streak_last_date or "").strip()
    if data.streak_count is None or not _DAY_KEY_RE.match(day):
        return
    count = max(int(data.streak_count), 0)
    current_day = (row.streak_last_date or "").strip()
    if not _DAY_KEY_RE.match(current_day) or day > current_day:
        row.streak_last_date = day
        row.streak_count = count
    elif day == current_day:
        row.streak_count = max(count, row.streak_count or 0)


def _parse_iso(value: str) -> datetime | None:
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _clean_labels(raw: list[str]) -> list[str]:
    labels: list[str] = []
    for item in raw[:50]:
        label = (item or "").strip()[:40]
        if label and label not in labels:
            labels.append(label)
    return labels


def _settings_out(row: UserSettings, user: User) -> SettingsSyncOut:
    return SettingsSyncOut(
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
        display_name=user.name,
        gender=user.gender or row.gender,
        birthdate=user.birthdate or row.birthdate,
        country=user.country,
        city=user.city,
        street=user.street,
        phone=user.phone,
        dark_mode=row.dark_mode,
        usage_started_at=row.usage_started_at,
        streak_count=row.streak_count,
        streak_last_date=row.streak_last_date,
        hidden_categories=list(row.hidden_categories or []),
        **photo_meta(),
        updated_at=row.updated_at,
    )


def _apply_transaction(db: Session, user_id: int, data: TransactionSyncIn) -> None:
    row = _get_by_client(db, Transaction, user_id, data.client_id)
    incoming = as_utc_or_now(data.updated_at or data.occurred_at)
    frequency, is_recurring, recurring_period = apply_frequency(data.frequency)
    if row is None:
        row = Transaction(user_id=user_id, client_id=data.client_id)
        db.add(row)
    elif not _newer_or_equal(incoming, row.updated_at):
        return
    row.type = data.type
    row.amount = data.amount
    row.currency_code = normalize_currency(data.currency_code)
    row.category = empty_to_none(data.category)
    row.payment_method = empty_to_none(data.payment_method)
    row.note = empty_to_none(data.note)
    row.source_id = empty_to_none(data.source_id)
    row.occurred_at = _keep_event_time(row.occurred_at, data.occurred_at)
    row.frequency = frequency
    row.period_key = empty_to_none(data.period_key)
    row.is_recurring = is_recurring
    row.recurring_period = recurring_period
    row.deleted_at = None
    row.updated_at = incoming


def _apply_goal(db: Session, user_id: int, data: GoalSyncIn) -> None:
    row = _get_by_client(db, SavingsGoal, user_id, data.client_id)
    incoming = as_utc_or_now(data.updated_at or data.created_at)
    if row is None:
        row = SavingsGoal(user_id=user_id, client_id=data.client_id)
        db.add(row)
    elif not _newer_or_equal(incoming, row.updated_at):
        return
    row.name = data.name
    row.currency_code = normalize_currency(data.currency_code)
    row.target_amount = data.target_amount
    row.duration = data.duration
    row.deadline = as_utc(data.deadline)
    row.allocate_percent = data.allocate_percent
    row.allocate_amount = data.allocate_amount
    row.deduct_frequency = data.deduct_frequency
    row.is_periodic = data.is_periodic
    row.duration_count = data.duration_count
    row.priority = data.priority
    row.completed_at = as_utc(data.completed_at)
    row.completed_amount = data.completed_amount
    row.is_completed = row.completed_at is not None
    if data.created_at is not None:
        row.created_at = as_utc_or_now(data.created_at)
    row.deleted_at = None
    row.updated_at = incoming


def _apply_transfer(db: Session, user_id: int, data: TransferSyncIn) -> None:
    row = _get_by_client(db, SavingsTransfer, user_id, data.client_id)
    incoming = as_utc_or_now(data.updated_at or data.occurred_at)
    goal = None
    goal_client_id = empty_to_none(data.goal_client_id)
    if goal_client_id is not None:
        goal = _get_by_client(db, SavingsGoal, user_id, goal_client_id)
    if row is None:
        row = SavingsTransfer(user_id=user_id, client_id=data.client_id)
        db.add(row)
    elif not _newer_or_equal(incoming, row.updated_at):
        return
    row.goal_id = None if goal is None else goal.id
    row.amount = data.amount
    row.currency_code = normalize_currency(data.currency_code)
    row.direction = direction_from_kind(data.kind, data.direction)
    row.kind = data.kind
    row.note = empty_to_none(data.note)
    row.occurred_at = _keep_event_time(row.occurred_at, data.occurred_at)
    row.processed_period_key = empty_to_none(data.processed_period_key)
    row.deleted_at = None
    row.updated_at = incoming


def _apply_list(db: Session, user_id: int, data: ShoppingListSyncIn) -> None:
    row = _get_by_client(db, ShoppingList, user_id, data.client_id)
    incoming = as_utc_or_now(data.updated_at)
    if row is None:
        row = ShoppingList(user_id=user_id, client_id=data.client_id)
        db.add(row)
    elif not _newer_or_equal(incoming, row.updated_at):
        return
    row.name = data.name
    row.deleted_at = None
    row.updated_at = incoming


def _apply_item(db: Session, user_id: int, data: ShoppingItemSyncIn) -> None:
    shopping_list = _get_by_client(db, ShoppingList, user_id, data.list_client_id)
    if shopping_list is None:
        shopping_list = ShoppingList(
            user_id=user_id,
            client_id=data.list_client_id,
            name="المشتريات",
        )
        db.add(shopping_list)
        db.flush()
    row = _get_by_client(db, ShoppingItem, user_id, data.client_id)
    incoming = as_utc_or_now(data.updated_at or data.created_at)
    if row is None:
        row = ShoppingItem(user_id=user_id, client_id=data.client_id)
        db.add(row)
    elif not _newer_or_equal(incoming, row.updated_at):
        return
    row.list_id = shopping_list.id
    row.name = data.name
    row.quantity = max(1, data.quantity)
    row.price = data.price
    row.is_purchased = data.is_purchased
    row.purchased_at = as_utc(data.purchased_at)
    row.expense_client_id = empty_to_none(data.expense_client_id)
    if data.created_at is not None:
        row.created_at = as_utc_or_now(data.created_at)
    row.deleted_at = None
    row.updated_at = incoming


def _apply_recurring(db: Session, user_id: int, data: RecurringSyncIn) -> None:
    row = _get_by_client(db, RecurringExpense, user_id, data.client_id)
    incoming = as_utc_or_now(data.updated_at or data.created_at)
    if row is None:
        row = RecurringExpense(user_id=user_id, client_id=data.client_id)
        db.add(row)
    elif not _newer_or_equal(incoming, row.updated_at):
        return
    row.amount = data.amount
    row.currency_code = normalize_currency(data.currency_code)
    row.category = data.category
    row.payment_method = data.payment_method
    row.note = empty_to_none(data.note)
    row.period = period_from_unit(data.unit)
    row.interval_count = max(1, data.interval_count)
    row.next_run_at = as_utc_or_now(data.next_due_at)
    row.is_active = data.enabled
    row.requires_confirmation = data.requires_confirmation
    row.remind_at = None if data.remind_at is None else as_utc_or_now(data.remind_at)
    row.remind_on_income = data.remind_on_income
    if data.created_at is not None:
        row.created_at = as_utc_or_now(data.created_at)
    row.deleted_at = None
    row.updated_at = incoming


def _apply_category(db: Session, user_id: int, data: CategorySyncIn) -> None:
    row = _get_by_client(db, ExpenseCategory, user_id, data.client_id)
    incoming = as_utc_or_now(data.updated_at or data.created_at)
    if row is None:
        row = ExpenseCategory(user_id=user_id, client_id=data.client_id)
        db.add(row)
    elif not _newer_or_equal(incoming, row.updated_at):
        return
    row.label = data.label.strip()
    row.icon_index = max(0, data.icon_index)
    row.deleted_at = None
    row.updated_at = incoming


def _apply_preset(db: Session, user_id: int, data: PresetSyncIn) -> None:
    row = _get_by_client(db, ExpensePreset, user_id, data.client_id)
    incoming = as_utc_or_now(data.updated_at or data.created_at)
    if row is None:
        row = ExpensePreset(user_id=user_id, client_id=data.client_id)
        db.add(row)
    elif not _newer_or_equal(incoming, row.updated_at):
        return
    row.amount = data.amount
    row.multiplier = data.multiplier
    row.currency_code = normalize_currency(data.currency_code)
    row.category = data.category
    row.payment_method = data.payment_method
    row.note = empty_to_none(data.note)
    row.recurring = data.recurring
    row.unit = data.unit
    row.interval_count = data.interval_count
    if data.created_at is not None:
        row.created_at = as_utc_or_now(data.created_at)
    row.deleted_at = None
    row.updated_at = incoming


def _apply_notification(db: Session, user_id: int, data: NotificationSyncIn) -> None:
    row = _get_by_client(db, Notification, user_id, data.client_id)
    if row is None:
        row = (
            db.query(Notification)
            .filter(
                Notification.user_id == user_id,
                Notification.event_key == data.event_key,
                Notification.deleted_at.is_(None),
            )
            .first()
        )
    incoming = as_utc_or_now(data.updated_at or data.created_at)
    if row is None:
        row = Notification(user_id=user_id, client_id=data.client_id)
        db.add(row)
    elif not _newer_or_equal(incoming, row.updated_at):
        return
    row.type = data.type
    row.title = data.title
    row.message = data.message
    row.event_key = data.event_key
    row.related_id = empty_to_none(data.related_id)
    row.event_metadata = data.metadata
    row.is_read = data.is_read
    if data.created_at is not None:
        row.created_at = as_utc_or_now(data.created_at)
    row.deleted_at = None
    row.updated_at = incoming


def _apply_deletes(db: Session, model, user_id: int, deletes: list[TombstoneIn]) -> None:
    for item in deletes:
        row = _get_by_client(db, model, user_id, item.client_id)
        if row is None:
            continue
        _apply_delete(row, item.deleted_at)


def _collection_out(live_rows, tombstones, serialize) -> SyncCollectionOut:
    return SyncCollectionOut(
        upserts=[serialize(row) for row in live_rows],
        deletes=tombstones,
    )


@router.post("/sync", response_model=SyncResponse)
def sync_changes(
    payload: SyncRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Apply the pushed changes, then return what changed since last_sync_at.

    Upserts run parent first (goals and lists before the rows that point at
    them), then tombstones, then settings. Everything happens in one
    transaction: a bad row rolls the whole push back.
    """
    # Its rate limit runs in RateLimitMiddleware, before the body is read.
    user_id = current_user.id
    last_sync = as_utc(payload.last_sync_at)

    try:
        # Upserts, parents first: goals and lists before the rows that point at them.
        for item in _parse_many(GoalSyncIn, payload.savings_goals.upserts):
            _apply_goal(db, user_id, item)
        for item in _parse_many(ShoppingListSyncIn, payload.shopping_lists.upserts):
            _apply_list(db, user_id, item)
        for item in _parse_many(TransactionSyncIn, payload.transactions.upserts):
            _apply_transaction(db, user_id, item)
        for item in _parse_many(TransferSyncIn, payload.savings_transfers.upserts):
            _apply_transfer(db, user_id, item)
        for item in _parse_many(ShoppingItemSyncIn, payload.shopping_items.upserts):
            _apply_item(db, user_id, item)
        for item in _parse_many(RecurringSyncIn, payload.recurring_expenses.upserts):
            _apply_recurring(db, user_id, item)
        for item in _parse_many(NotificationSyncIn, payload.notifications.upserts):
            _apply_notification(db, user_id, item)
        for item in _parse_many(CategorySyncIn, payload.expense_categories.upserts):
            _apply_category(db, user_id, item)
        for item in _parse_many(PresetSyncIn, payload.expense_presets.upserts):
            _apply_preset(db, user_id, item)

        # Tombstones, children first, so a list goes after its items.
        _apply_deletes(db, ShoppingItem, user_id, payload.shopping_items.deletes)
        _apply_deletes(db, SavingsTransfer, user_id, payload.savings_transfers.deletes)
        _apply_deletes(db, Transaction, user_id, payload.transactions.deletes)
        _apply_deletes(db, RecurringExpense, user_id, payload.recurring_expenses.deletes)
        _apply_deletes(db, Notification, user_id, payload.notifications.deletes)
        _apply_deletes(db, ExpenseCategory, user_id, payload.expense_categories.deletes)
        _apply_deletes(db, ExpensePreset, user_id, payload.expense_presets.deletes)
        _apply_deletes(db, SavingsGoal, user_id, payload.savings_goals.deletes)
        _apply_deletes(db, ShoppingList, user_id, payload.shopping_lists.deletes)

        # Settings: one row per user, created here if it is missing.
        settings, settings_created = _settings_row(db, current_user)
        if payload.settings is not None:
            _apply_settings(
                settings,
                current_user,
                payload.settings,
                created=settings_created,
            )

        # Reply: every row changed since last_sync_at, live rows and tombstones apart.
        db.flush()
        server_time = utc_now()

        def dump_changed(model, serialize_live):
            rows = _changed_since(
                db.query(model).filter(model.user_id == user_id),
                model,
                last_sync,
            ).all()
            live = [row for row in rows if row.deleted_at is None]
            deleted = [
                TombstoneIn(client_id=row.client_id, deleted_at=row.deleted_at)
                for row in rows
                if row.deleted_at is not None
            ]
            return _collection_out(live, deleted, serialize_live)

        # Lookups that turn foreign keys back into client ids.
        goals = {row.id: row for row in db.query(SavingsGoal).filter(SavingsGoal.user_id == user_id).all()}
        lists = {row.id: row for row in db.query(ShoppingList).filter(ShoppingList.user_id == user_id).all()}

        response = SyncResponse(
            server_time=server_time,
            transactions=dump_changed(
                Transaction,
                lambda row: {
                    "client_id": row.client_id,
                    "type": row.type,
                    "amount": str(row.amount),
                    "currency_code": row.currency_code,
                    "category": row.category,
                    "payment_method": row.payment_method,
                    "note": row.note,
                    "source_id": row.source_id,
                    "occurred_at": row.occurred_at,
                    "frequency": row.frequency,
                    "period_key": row.period_key,
                    "created_at": row.created_at,
                    "updated_at": row.updated_at,
                },
            ),
            savings_goals=dump_changed(
                SavingsGoal,
                lambda row: {
                    "client_id": row.client_id,
                    "name": row.name,
                    "currency_code": row.currency_code,
                    "target_amount": str(row.target_amount),
                    "duration": row.duration,
                    "deadline": row.deadline,
                    "allocate_percent": None if row.allocate_percent is None else str(row.allocate_percent),
                    "allocate_amount": None if row.allocate_amount is None else str(row.allocate_amount),
                    "deduct_frequency": row.deduct_frequency,
                    "is_periodic": row.is_periodic,
                    "duration_count": row.duration_count,
                    "priority": row.priority,
                    "completed_at": row.completed_at,
                    "completed_amount": None if row.completed_amount is None else str(row.completed_amount),
                    "created_at": row.created_at,
                    "updated_at": row.updated_at,
                },
            ),
            savings_transfers=dump_changed(
                SavingsTransfer,
                lambda row: {
                    "client_id": row.client_id,
                    "goal_client_id": None if row.goal_id is None else getattr(goals.get(row.goal_id), "client_id", None),
                    "amount": str(row.amount),
                    "currency_code": row.currency_code,
                    "direction": row.direction,
                    "kind": row.kind,
                    "note": row.note,
                    "occurred_at": row.occurred_at,
                    "processed_period_key": row.processed_period_key,
                    "created_at": row.created_at,
                    "updated_at": row.updated_at,
                },
            ),
            shopping_lists=dump_changed(
                ShoppingList,
                lambda row: {
                    "client_id": row.client_id,
                    "name": row.name,
                    "created_at": row.created_at,
                    "updated_at": row.updated_at,
                },
            ),
            shopping_items=dump_changed(
                ShoppingItem,
                lambda row: {
                    "client_id": row.client_id,
                    "list_client_id": getattr(lists.get(row.list_id), "client_id", "shopping_default"),
                    "name": row.name,
                    "quantity": row.quantity,
                    "price": None if row.price is None else str(row.price),
                    "is_purchased": row.is_purchased,
                    "purchased_at": row.purchased_at,
                    "expense_client_id": row.expense_client_id,
                    "created_at": row.created_at,
                    "updated_at": row.updated_at,
                },
            ),
            recurring_expenses=dump_changed(
                RecurringExpense,
                lambda row: {
                    "client_id": row.client_id,
                    "amount": str(row.amount),
                    "currency_code": row.currency_code,
                    "category": row.category,
                    "payment_method": row.payment_method,
                    "note": row.note,
                    "unit": unit_from_period(row.period),
                    "interval_count": row.interval_count,
                    "next_due_at": row.next_run_at,
                    "enabled": row.is_active,
                    "requires_confirmation": bool(row.requires_confirmation),
                    "remind_at": row.remind_at,
                    "remind_on_income": bool(row.remind_on_income),
                    "created_at": row.created_at,
                    "updated_at": row.updated_at,
                },
            ),
            notifications=dump_changed(
                Notification,
                lambda row: {
                    "client_id": row.client_id,
                    "type": row.type,
                    "title": row.title,
                    "message": row.message,
                    "event_key": row.event_key,
                    "related_id": row.related_id,
                    "metadata": row.event_metadata or {},
                    "is_read": row.is_read,
                    "created_at": row.created_at,
                    "updated_at": row.updated_at,
                },
            ),
            expense_categories=dump_changed(
                ExpenseCategory,
                lambda row: {
                    "client_id": row.client_id,
                    "label": row.label,
                    "icon_index": row.icon_index,
                    "created_at": row.created_at,
                    "updated_at": row.updated_at,
                },
            ),
            expense_presets=dump_changed(
                ExpensePreset,
                lambda row: {
                    "client_id": row.client_id,
                    "amount": str(row.amount),
                    "multiplier": row.multiplier,
                    "currency_code": row.currency_code,
                    "category": row.category,
                    "payment_method": row.payment_method,
                    "note": row.note,
                    "recurring": row.recurring,
                    "unit": row.unit,
                    "interval_count": row.interval_count,
                    "created_at": row.created_at,
                    "updated_at": row.updated_at,
                },
            ),
            settings=_settings_out(settings, current_user),
        )
        db.commit()
        return response
    except HTTPException:
        db.rollback()
        raise
    except Exception as error:
        db.rollback()
        # The details name tables and SQL; they stay in the server log.
        logger.exception("sync failed for user %s", user_id)
        raise HTTPException(status_code=400, detail="Sync failed") from error
