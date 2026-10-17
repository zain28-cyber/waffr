"""Bodies for POST /sync: one *SyncIn model per collection, the request and
the response.

Rows arrive as plain dicts and are parsed one by one in routers/sync.py, so
a bad row gets a 422 that names it.
"""

from datetime import datetime
from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, Field, field_serializer, field_validator

from api_schemas import money_str, parse_decimal
from input_rules import INT_MAX, MONEY_MAX, CleanModel

# Private text arrives encrypted, which is longer than what the user typed.
PRIVATE_TEXT_MAX = 4000
# Notes and other free text the app does not cap; this only stops abuse.
FREE_TEXT_MAX = 20_000
# One request carries at most this many rows per collection. A first sync
# sends the whole ledger, so this is far above any real account.
SYNC_ROWS_MAX = 50_000
ID_MAX = 64


class TombstoneIn(CleanModel):
    """A deleted row: its client id and when it was deleted."""

    client_id: str = Field(min_length=1, max_length=ID_MAX)
    deleted_at: datetime | None = None


class TransactionSyncIn(CleanModel):
    """A transaction as the app pushes it."""

    client_id: str = Field(min_length=1, max_length=ID_MAX)
    type: str = Field(pattern="^(income|expense)$")
    amount: Decimal = Field(gt=0, le=MONEY_MAX)
    category: str | None = Field(default=None, max_length=FREE_TEXT_MAX)
    payment_method: str | None = Field(default=None, max_length=FREE_TEXT_MAX)
    note: str | None = Field(default=None, max_length=FREE_TEXT_MAX)
    source_id: str | None = Field(default=None, max_length=255)
    occurred_at: datetime | None = None
    frequency: str = Field(default="none", pattern="^(none|weekly|monthly)$")
    period_key: str | None = Field(default=None, max_length=50)
    currency_code: str | None = Field(default=None, max_length=16)
    updated_at: datetime | None = None

    @field_validator("amount", mode="before")
    @classmethod
    def _amount(cls, value):
        parsed = parse_decimal(value)
        if parsed is None:
            raise ValueError("amount is required")
        return parsed


class GoalSyncIn(CleanModel):
    """A savings goal as the app pushes it."""

    client_id: str = Field(min_length=1, max_length=ID_MAX)
    name: str = Field(min_length=1, max_length=PRIVATE_TEXT_MAX)
    target_amount: Decimal = Field(gt=0, le=MONEY_MAX)
    duration: str = Field(
        default="month",
        pattern="^(week|month|threeMonths|sixMonths|year)$",
    )
    deadline: datetime | None = None
    allocate_percent: Decimal | None = Field(default=None, ge=-MONEY_MAX, le=MONEY_MAX)
    allocate_amount: Decimal | None = Field(default=None, ge=-MONEY_MAX, le=MONEY_MAX)
    deduct_frequency: str = Field(default="monthly", pattern="^(none|weekly|monthly)$")
    is_periodic: bool = False
    duration_count: int | None = Field(default=None, ge=-INT_MAX, le=INT_MAX)
    priority: int = Field(default=0, ge=-INT_MAX, le=INT_MAX)
    completed_at: datetime | None = None
    completed_amount: Decimal | None = Field(default=None, ge=-MONEY_MAX, le=MONEY_MAX)
    currency_code: str | None = Field(default=None, max_length=16)
    created_at: datetime | None = None
    updated_at: datetime | None = None

    @field_validator(
        "target_amount",
        "allocate_percent",
        "allocate_amount",
        "completed_amount",
        mode="before",
    )
    @classmethod
    def _money(cls, value):
        return parse_decimal(value)


class TransferSyncIn(CleanModel):
    """A savings transfer as the app pushes it; the goal is named by client id."""

    client_id: str = Field(min_length=1, max_length=ID_MAX)
    goal_client_id: str | None = Field(default=None, max_length=ID_MAX)
    amount: Decimal = Field(gt=0, le=MONEY_MAX)
    direction: str | None = Field(
        default=None,
        pattern="^(to_savings|to_balance)$",
    )
    kind: str | None = Field(
        default=None,
        pattern="^(periodLeftover|goalPeriodic|manual|withdraw)$",
    )
    note: str | None = Field(default=None, max_length=FREE_TEXT_MAX)
    occurred_at: datetime | None = None
    processed_period_key: str | None = Field(default=None, max_length=50)
    currency_code: str | None = Field(default=None, max_length=16)
    updated_at: datetime | None = None

    @field_validator("amount", mode="before")
    @classmethod
    def _amount(cls, value):
        parsed = parse_decimal(value)
        if parsed is None:
            raise ValueError("amount is required")
        return parsed


class ShoppingListSyncIn(CleanModel):
    """A shopping list as the app pushes it."""

    client_id: str = Field(min_length=1, max_length=ID_MAX)
    name: str = Field(min_length=1, max_length=100)
    updated_at: datetime | None = None


class ShoppingItemSyncIn(CleanModel):
    """A shopping item as the app pushes it; the list is named by client id."""

    client_id: str = Field(min_length=1, max_length=ID_MAX)
    list_client_id: str = Field(default="shopping_default", max_length=ID_MAX)
    name: str = Field(min_length=1, max_length=PRIVATE_TEXT_MAX)
    quantity: int = Field(default=1, ge=-INT_MAX, le=INT_MAX)
    price: Decimal | None = Field(default=None, ge=0, le=MONEY_MAX)
    is_purchased: bool = False
    purchased_at: datetime | None = None
    expense_client_id: str | None = Field(default=None, max_length=ID_MAX)
    created_at: datetime | None = None
    updated_at: datetime | None = None

    @field_validator("price", mode="before")
    @classmethod
    def _price(cls, value):
        return parse_decimal(value)


class RecurringSyncIn(CleanModel):
    """A recurring expense as the app pushes it."""

    client_id: str = Field(min_length=1, max_length=ID_MAX)
    amount: Decimal = Field(gt=0, le=MONEY_MAX)
    category: str = Field(max_length=FREE_TEXT_MAX)
    payment_method: str = Field(default="", max_length=FREE_TEXT_MAX)
    note: str | None = Field(default=None, max_length=FREE_TEXT_MAX)
    unit: str = Field(default="month", max_length=10)
    interval_count: int = Field(default=1, ge=-INT_MAX, le=INT_MAX)
    next_due_at: datetime | None = None
    enabled: bool = True
    requires_confirmation: bool = False
    remind_at: datetime | None = None
    remind_on_income: bool = False
    currency_code: str | None = Field(default=None, max_length=16)
    created_at: datetime | None = None
    updated_at: datetime | None = None

    @field_validator("amount", mode="before")
    @classmethod
    def _amount(cls, value):
        parsed = parse_decimal(value)
        if parsed is None:
            raise ValueError("amount is required")
        return parsed


class NotificationSyncIn(CleanModel):
    """A notification as the app pushes it."""

    client_id: str = Field(min_length=1, max_length=ID_MAX)
    type: str = Field(max_length=50)
    title: str = Field(max_length=FREE_TEXT_MAX)
    message: str = Field(max_length=FREE_TEXT_MAX)
    event_key: str = Field(max_length=255)
    related_id: str | None = Field(default=None, max_length=ID_MAX)
    metadata: dict[str, str] = Field(default_factory=dict, max_length=50)
    is_read: bool = False
    created_at: datetime | None = None
    updated_at: datetime | None = None


class CategorySyncIn(CleanModel):
    """A custom category as the app pushes it."""

    client_id: str = Field(min_length=1, max_length=ID_MAX)
    label: str = Field(min_length=1, max_length=PRIVATE_TEXT_MAX)
    icon_index: int = Field(default=0, ge=-INT_MAX, le=INT_MAX)
    created_at: datetime | None = None
    updated_at: datetime | None = None


class PresetSyncIn(CleanModel):
    """An expense preset as the app pushes it."""

    client_id: str = Field(min_length=1, max_length=ID_MAX)
    amount: Decimal = Field(gt=0, le=MONEY_MAX)
    multiplier: int = Field(default=1, ge=1, le=10)
    currency_code: str | None = Field(default=None, max_length=16)
    category: str = Field(min_length=1, max_length=PRIVATE_TEXT_MAX)
    payment_method: str = Field(default="", max_length=PRIVATE_TEXT_MAX)
    note: str | None = Field(default=None, max_length=PRIVATE_TEXT_MAX)
    recurring: bool = False
    unit: str = Field(default="month", pattern="^(day|week|month)$")
    interval_count: int = Field(default=1, ge=1, le=99)
    created_at: datetime | None = None
    updated_at: datetime | None = None

    @field_validator("amount", mode="before")
    @classmethod
    def _amount(cls, value):
        parsed = parse_decimal(value)
        if parsed is None:
            raise ValueError("amount is required")
        return parsed


class SettingsSyncIn(CleanModel):
    """The settings object; fields left out are not changed."""

    notifications_muted: bool | None = None
    notifications_enabled: bool | None = None
    notify_low_balance: bool | None = None
    notify_spending_threshold: bool | None = None
    notify_goal_reached: bool | None = None
    notify_recurring_expense: bool | None = None
    ai_data_enabled: bool | None = None
    monthly_income_amount: Decimal | None = Field(default=None, ge=-MONEY_MAX, le=MONEY_MAX)
    weekly_income_amount: Decimal | None = Field(default=None, ge=-MONEY_MAX, le=MONEY_MAX)
    income_overrides_by_currency: dict | None = Field(default=None, max_length=100)
    enabled_currencies: list[str] | None = Field(default=None, max_length=100)
    active_currency: str | None = Field(default=None, max_length=16)
    processed_period_keys: list[Annotated[str, Field(max_length=100)]] | None = Field(
        default=None,
        max_length=20_000,
    )
    display_name: str | None = Field(default=None, max_length=100)
    gender: str | None = Field(default=None, max_length=20)
    birthdate: str | None = Field(default=None, max_length=40)
    country: str | None = Field(default=None, max_length=80)
    city: str | None = Field(default=None, max_length=80)
    street: str | None = Field(default=None, max_length=160)
    phone: str | None = Field(default=None, max_length=32)
    dark_mode: bool | None = None
    usage_started_at: str | None = Field(default=None, max_length=40)
    streak_count: int | None = Field(default=None, ge=-INT_MAX, le=INT_MAX)
    streak_last_date: str | None = Field(default=None, max_length=10)
    hidden_categories: list[str] | None = Field(default=None, max_length=500)
    updated_at: datetime | None = None

    @field_validator("monthly_income_amount", "weekly_income_amount", mode="before")
    @classmethod
    def _money(cls, value):
        return parse_decimal(value)


# Rows are cleaned when each one is parsed into its *SyncIn model.
class SyncCollectionIn(BaseModel):
    """One collection of a push: rows to upsert and tombstones."""

    upserts: list[dict] = Field(default_factory=list, max_length=SYNC_ROWS_MAX)
    deletes: list[TombstoneIn] = Field(default_factory=list, max_length=SYNC_ROWS_MAX)


class SyncRequest(BaseModel):
    """Body of POST /sync."""

    last_sync_at: datetime | None = None
    transactions: SyncCollectionIn = Field(default_factory=SyncCollectionIn)
    savings_goals: SyncCollectionIn = Field(default_factory=SyncCollectionIn)
    savings_transfers: SyncCollectionIn = Field(default_factory=SyncCollectionIn)
    shopping_lists: SyncCollectionIn = Field(default_factory=SyncCollectionIn)
    shopping_items: SyncCollectionIn = Field(default_factory=SyncCollectionIn)
    recurring_expenses: SyncCollectionIn = Field(default_factory=SyncCollectionIn)
    notifications: SyncCollectionIn = Field(default_factory=SyncCollectionIn)
    expense_categories: SyncCollectionIn = Field(default_factory=SyncCollectionIn)
    expense_presets: SyncCollectionIn = Field(default_factory=SyncCollectionIn)
    settings: SettingsSyncIn | None = None


class SettingsSyncOut(BaseModel):
    """The full settings object returned by every sync."""

    notifications_enabled: bool
    notifications_muted: bool
    notify_low_balance: bool
    notify_spending_threshold: bool
    notify_goal_reached: bool
    notify_recurring_expense: bool
    ai_data_enabled: bool
    monthly_income_amount: Decimal | None
    weekly_income_amount: Decimal | None
    income_overrides_by_currency: dict = Field(default_factory=dict)
    enabled_currencies: list[str] = Field(default_factory=lambda: ["SYP"])
    active_currency: str = "SYP"
    processed_period_keys: list[str]
    display_name: str | None = None
    gender: str | None = None
    birthdate: str | None = None
    country: str | None = None
    city: str | None = None
    street: str | None = None
    phone: str | None = None
    dark_mode: bool | None = None
    usage_started_at: str | None = None
    streak_count: int | None = None
    streak_last_date: str | None = None
    hidden_categories: list[str] = Field(default_factory=list)
    has_photo: bool = False
    photo_updated_at: datetime | None = None
    updated_at: datetime

    @field_serializer("monthly_income_amount", "weekly_income_amount")
    def _money(self, value: Decimal | None) -> str | None:
        return money_str(value)


class SyncCollectionOut(BaseModel):
    """One collection of the reply: live rows and tombstones."""

    upserts: list[dict] = Field(default_factory=list)
    deletes: list[TombstoneIn] = Field(default_factory=list)


class SyncResponse(BaseModel):
    """Reply of POST /sync. ``server_time`` is the next last_sync_at."""

    server_time: datetime
    transactions: SyncCollectionOut
    savings_goals: SyncCollectionOut
    savings_transfers: SyncCollectionOut
    shopping_lists: SyncCollectionOut
    shopping_items: SyncCollectionOut
    recurring_expenses: SyncCollectionOut
    notifications: SyncCollectionOut
    expense_categories: SyncCollectionOut
    expense_presets: SyncCollectionOut
    settings: SettingsSyncOut
