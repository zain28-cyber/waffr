"""Request and response bodies for the REST routes in routers/.

Money travels as strings with two decimals; the sync bodies are in
sync_schemas.py.
"""

from datetime import datetime
from decimal import Decimal
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_serializer, field_validator

from input_rules import INT_MAX, MONEY_MAX, CleanModel


def parse_decimal(value: Any) -> Decimal | None:
    """A Decimal from a number or string; None for None or ""."""
    if value is None or value == "":
        return None
    return Decimal(str(value))


class ApiModel(BaseModel):
    """Response model that reads straight from ORM rows."""

    model_config = ConfigDict(from_attributes=True)


def money_str(value: Decimal | None) -> str | None:
    """Format money with two decimals, e.g. "12.50"; None stays None."""
    if value is None:
        return None
    quantized = value.quantize(Decimal("0.01"))
    return format(quantized, "f")


class TransactionCreate(CleanModel):
    """Body of POST /transactions."""

    client_id: str | None = Field(default=None, max_length=64)
    type: str = Field(pattern="^(income|expense)$")
    amount: Decimal = Field(gt=0, le=MONEY_MAX)
    category: str | None = Field(default=None, max_length=100)
    payment_method: str | None = Field(default=None, max_length=100)
    note: str | None = Field(default=None, max_length=255)
    source_id: str | None = Field(default=None, max_length=255)
    occurred_at: datetime | None = None
    frequency: str = Field(default="none", pattern="^(none|weekly|monthly)$")
    period_key: str | None = Field(default=None, max_length=50)

    @field_validator("amount", mode="before")
    @classmethod
    def _amount(cls, value):
        parsed = parse_decimal(value)
        if parsed is None:
            raise ValueError("amount is required")
        return parsed


class TransactionUpdate(CleanModel):
    """Body of PATCH /transactions/{id}; only the fields sent change."""

    amount: Decimal | None = Field(default=None, gt=0, le=MONEY_MAX)
    category: str | None = Field(default=None, max_length=100)
    payment_method: str | None = Field(default=None, max_length=100)
    note: str | None = Field(default=None, max_length=255)
    occurred_at: datetime | None = None
    frequency: str | None = Field(default=None, pattern="^(none|weekly|monthly)$")
    period_key: str | None = Field(default=None, max_length=50)

    @field_validator("amount", mode="before")
    @classmethod
    def _amount(cls, value):
        return parse_decimal(value)


class TransactionOut(ApiModel):
    """A transaction as the REST routes return it."""

    id: int
    client_id: str
    type: str
    amount: Decimal
    currency_code: str = "SYP"
    category: str | None
    payment_method: str | None
    note: str | None
    source_id: str | None
    occurred_at: datetime
    frequency: str
    period_key: str | None
    created_at: datetime
    updated_at: datetime

    @field_serializer("amount")
    def _amount(self, value: Decimal) -> str:
        return money_str(value) or "0.00"


class SavingsGoalCreate(CleanModel):
    """Body of POST /savings-goals."""

    client_id: str | None = Field(default=None, max_length=64)
    name: str = Field(min_length=1, max_length=100)
    target_amount: Decimal = Field(gt=0, le=MONEY_MAX)
    duration: str = Field(
        default="month",
        pattern="^(week|month|threeMonths|sixMonths|year)$",
    )
    deadline: datetime | None = None
    allocate_percent: Decimal | None = Field(default=None, ge=0, le=MONEY_MAX)
    allocate_amount: Decimal | None = Field(default=None, ge=0, le=MONEY_MAX)
    deduct_frequency: str = Field(
        default="monthly",
        pattern="^(none|weekly|monthly)$",
    )
    is_periodic: bool = False
    duration_count: int | None = Field(default=None, ge=1, le=INT_MAX)
    priority: int | None = Field(default=None, ge=0, le=INT_MAX)
    completed_at: datetime | None = None
    completed_amount: Decimal | None = Field(default=None, ge=0, le=MONEY_MAX)

    @field_validator("name")
    @classmethod
    def _name(cls, value: str) -> str:
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("name is required")
        return trimmed

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


class SavingsGoalUpdate(CleanModel):
    """Body of PATCH /savings-goals/{id}; only the fields sent change."""

    name: str | None = Field(default=None, min_length=1, max_length=100)
    target_amount: Decimal | None = Field(default=None, gt=0, le=MONEY_MAX)
    duration: str | None = Field(
        default=None,
        pattern="^(week|month|threeMonths|sixMonths|year)$",
    )
    deadline: datetime | None = None
    allocate_percent: Decimal | None = Field(default=None, ge=0, le=MONEY_MAX)
    allocate_amount: Decimal | None = Field(default=None, ge=0, le=MONEY_MAX)
    deduct_frequency: str | None = Field(
        default=None,
        pattern="^(none|weekly|monthly)$",
    )
    is_periodic: bool | None = None
    duration_count: int | None = Field(default=None, ge=1, le=INT_MAX)
    priority: int | None = Field(default=None, ge=0, le=INT_MAX)
    completed_at: datetime | None = None
    completed_amount: Decimal | None = Field(default=None, ge=0, le=MONEY_MAX)
    is_completed: bool | None = None

    @field_validator("name")
    @classmethod
    def _name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("name cannot be empty")
        return trimmed

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


class SavingsGoalOut(ApiModel):
    """A goal with its derived saved amount."""

    id: int
    client_id: str
    name: str
    currency_code: str = "SYP"
    target_amount: Decimal
    saved_amount: Decimal
    duration: str
    deadline: datetime | None
    allocate_percent: Decimal | None
    allocate_amount: Decimal | None
    deduct_frequency: str
    is_periodic: bool
    duration_count: int | None
    priority: int
    completed_at: datetime | None
    completed_amount: Decimal | None
    is_completed: bool
    created_at: datetime
    updated_at: datetime

    @field_serializer(
        "target_amount",
        "saved_amount",
        "allocate_percent",
        "allocate_amount",
        "completed_amount",
    )
    def _money(self, value: Decimal | None) -> str | None:
        return money_str(value)


class SavingsTransferCreate(CleanModel):
    """Body of POST /savings-transfers. The goal is named by id or client id."""

    client_id: str | None = Field(default=None, max_length=64)
    goal_id: int | None = None
    goal_client_id: str | None = Field(default=None, max_length=64)
    amount: Decimal = Field(gt=0, le=MONEY_MAX)
    direction: str | None = Field(
        default=None,
        pattern="^(to_savings|to_balance)$",
    )
    kind: str | None = Field(
        default=None,
        pattern="^(periodLeftover|goalPeriodic|manual|withdraw)$",
    )
    note: str | None = Field(default=None, max_length=255)
    occurred_at: datetime | None = None
    processed_period_key: str | None = Field(default=None, max_length=50)

    @field_validator("amount", mode="before")
    @classmethod
    def _amount(cls, value):
        parsed = parse_decimal(value)
        if parsed is None:
            raise ValueError("amount is required")
        return parsed


class SavingsTransferOut(ApiModel):
    """A savings transfer as the REST routes return it."""

    id: int
    client_id: str
    goal_id: int | None
    amount: Decimal
    currency_code: str = "SYP"
    direction: str
    kind: str | None
    note: str | None
    occurred_at: datetime
    processed_period_key: str | None
    created_at: datetime

    @field_serializer("amount")
    def _amount(self, value: Decimal) -> str:
        return money_str(value) or "0.00"


class ShoppingListCreate(CleanModel):
    """Body of POST /shopping-lists."""

    client_id: str | None = Field(default=None, max_length=64)
    name: str = Field(min_length=1, max_length=100)

    @field_validator("name")
    @classmethod
    def _name(cls, value: str) -> str:
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("name is required")
        return trimmed


class ShoppingListUpdate(CleanModel):
    """Body of PATCH /shopping-lists/{id}."""

    name: str | None = Field(default=None, min_length=1, max_length=100)

    @field_validator("name")
    @classmethod
    def _name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("name cannot be empty")
        return trimmed


class ShoppingItemCreate(CleanModel):
    """Body of POST /shopping-lists/{id}/items."""

    client_id: str | None = Field(default=None, max_length=64)
    name: str = Field(min_length=1, max_length=255)
    quantity: int = Field(default=1, ge=1, le=INT_MAX)
    price: Decimal | None = Field(default=None, ge=0, le=MONEY_MAX)
    is_purchased: bool = False
    purchased_at: datetime | None = None
    expense_client_id: str | None = Field(default=None, max_length=64)

    @field_validator("name")
    @classmethod
    def _name(cls, value: str) -> str:
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("name is required")
        return trimmed

    @field_validator("price", mode="before")
    @classmethod
    def _price(cls, value):
        return parse_decimal(value)


class ShoppingItemUpdate(CleanModel):
    """Body of PATCH /shopping-lists/{id}/items/{item_id}."""

    name: str | None = Field(default=None, min_length=1, max_length=255)
    quantity: int | None = Field(default=None, ge=1, le=INT_MAX)
    price: Decimal | None = Field(default=None, ge=0, le=MONEY_MAX)
    is_purchased: bool | None = None
    purchased_at: datetime | None = None
    expense_client_id: str | None = Field(default=None, max_length=64)

    @field_validator("name")
    @classmethod
    def _name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("name cannot be empty")
        return trimmed

    @field_validator("price", mode="before")
    @classmethod
    def _price(cls, value):
        return parse_decimal(value)


class ShoppingItemOut(ApiModel):
    """A shopping item as the REST routes return it."""

    id: int
    client_id: str
    list_id: int
    name: str
    quantity: int
    price: Decimal | None
    is_purchased: bool
    purchased_at: datetime | None
    expense_client_id: str | None
    created_at: datetime
    updated_at: datetime

    @field_serializer("price")
    def _price(self, value: Decimal | None) -> str | None:
        return money_str(value)


class ShoppingListOut(ApiModel):
    """A shopping list with its live items, newest first."""

    id: int
    client_id: str
    name: str
    created_at: datetime
    updated_at: datetime
    items: list[ShoppingItemOut] = []


class RecurringExpenseCreate(CleanModel):
    """Body of POST /recurring-expenses."""

    client_id: str | None = Field(default=None, max_length=64)
    amount: Decimal = Field(gt=0, le=MONEY_MAX)
    category: str = Field(min_length=1, max_length=100)
    payment_method: str = Field(default="", max_length=100)
    note: str | None = Field(default=None, max_length=255)
    unit: str = Field(pattern="^(day|week|month|daily|weekly|monthly)$")
    interval_count: int = Field(default=1, ge=1, le=INT_MAX)
    next_due_at: datetime | None = None
    enabled: bool = True

    @field_validator("category")
    @classmethod
    def _category(cls, value: str) -> str:
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("category is required")
        return trimmed

    @field_validator("amount", mode="before")
    @classmethod
    def _amount(cls, value):
        parsed = parse_decimal(value)
        if parsed is None:
            raise ValueError("amount is required")
        return parsed


class RecurringExpenseUpdate(CleanModel):
    """Body of PATCH /recurring-expenses/{id}; only the fields sent change."""

    amount: Decimal | None = Field(default=None, gt=0, le=MONEY_MAX)
    category: str | None = Field(default=None, min_length=1, max_length=100)
    payment_method: str | None = Field(default=None, max_length=100)
    note: str | None = Field(default=None, max_length=255)
    unit: str | None = Field(
        default=None,
        pattern="^(day|week|month|daily|weekly|monthly)$",
    )
    interval_count: int | None = Field(default=None, ge=1, le=INT_MAX)
    next_due_at: datetime | None = None
    enabled: bool | None = None

    @field_validator("amount", mode="before")
    @classmethod
    def _amount(cls, value):
        return parse_decimal(value)


class RecurringExpenseOut(ApiModel):
    """A recurring expense, with its period given as a unit."""

    id: int
    client_id: str
    amount: Decimal
    currency_code: str = "SYP"
    category: str
    payment_method: str
    note: str | None
    unit: str
    interval_count: int
    next_due_at: datetime
    enabled: bool
    created_at: datetime
    updated_at: datetime

    @field_serializer("amount")
    def _amount(self, value: Decimal) -> str:
        return money_str(value) or "0.00"


class NotificationCreate(CleanModel):
    """Body of POST /notifications."""

    client_id: str | None = Field(default=None, max_length=64)
    type: str = Field(min_length=1, max_length=50)
    title: str = Field(min_length=1, max_length=255)
    message: str = Field(min_length=1, max_length=20_000)
    event_key: str = Field(min_length=1, max_length=255)
    related_id: str | None = Field(default=None, max_length=64)
    metadata: dict[str, str] = Field(default_factory=dict, max_length=50)
    is_read: bool = False
    created_at: datetime | None = None


class NotificationUpdate(CleanModel):
    """Body of PATCH /notifications/{id}."""

    is_read: bool | None = None


class NotificationOut(ApiModel):
    """A notification as the REST routes return it."""

    id: int
    client_id: str
    type: str
    title: str
    message: str
    is_read: bool
    event_key: str
    related_id: str | None
    metadata: dict[str, str]
    created_at: datetime


class UserSettingsUpdate(CleanModel):
    """Body of PATCH /settings; only the fields sent change."""

    notifications_enabled: bool | None = None
    notifications_muted: bool | None = None
    notify_low_balance: bool | None = None
    notify_spending_threshold: bool | None = None
    notify_goal_reached: bool | None = None
    notify_recurring_expense: bool | None = None
    ai_data_enabled: bool | None = None
    monthly_income_amount: Decimal | None = Field(default=None, ge=0, le=MONEY_MAX)
    weekly_income_amount: Decimal | None = Field(default=None, ge=0, le=MONEY_MAX)
    processed_period_keys: list[str] | None = Field(default=None, max_length=20_000)

    @field_validator("monthly_income_amount", "weekly_income_amount", mode="before")
    @classmethod
    def _money(cls, value):
        return parse_decimal(value)


class UserSettingsOut(ApiModel):
    """The settings row as GET and PATCH /settings return it."""

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
    updated_at: datetime

    @field_serializer("monthly_income_amount", "weekly_income_amount")
    def _money(self, value: Decimal | None) -> str | None:
        return money_str(value)


class NewsArticleOut(ApiModel):
    """One stored news article."""

    id: int
    title: str
    source: str
    published_at: datetime
    url: str
    summary: str | None = None


class NewsRefreshOut(BaseModel):
    """Outcome of POST /online/news/refresh."""

    ok: bool
    fetched: int = 0
    matched: int = 0
    saved: int = 0
    error: str | None = None
