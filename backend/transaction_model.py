"""Income and expense rows, and the recurring expenses that create them."""

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import MONEY, Base, ClientIdMixin, SoftDeleteMixin, TimestampMixin, utc_now


class Transaction(ClientIdMixin, SoftDeleteMixin, TimestampMixin, Base):
    """One income or expense."""

    __tablename__ = "transactions"
    __table_args__ = (
        UniqueConstraint("user_id", "client_id", name="uq_transactions_user_client"),
        CheckConstraint("type IN ('income', 'expense')", name="ck_transactions_type"),
        CheckConstraint("amount > 0", name="ck_transactions_amount_positive"),
        CheckConstraint(
            "frequency IN ('none', 'weekly', 'monthly')",
            name="ck_transactions_frequency",
        ),
        Index("ix_transactions_user_updated", "user_id", "updated_at"),
        Index("ix_transactions_user_created", "user_id", "created_at"),
        Index("ix_transactions_user_occurred", "user_id", "occurred_at"),
        Index(
            "uq_transactions_user_source",
            "user_id",
            "source_id",
            unique=True,
            postgresql_where=text("source_id IS NOT NULL"),
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )

    type: Mapped[str] = mapped_column(String(20), nullable=False)
    amount: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    currency_code: Mapped[str] = mapped_column(
        String(10),
        default="SYP",
        nullable=False,
    )
    category: Mapped[str | None] = mapped_column(Text, nullable=True)
    payment_method: Mapped[str | None] = mapped_column(Text, nullable=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )
    frequency: Mapped[str] = mapped_column(
        String(20),
        default="none",
        nullable=False,
    )
    period_key: Mapped[str | None] = mapped_column(String(50), nullable=True)

    is_recurring: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    recurring_period: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )

    user: Mapped["User"] = relationship(back_populates="transactions")


class RecurringExpense(ClientIdMixin, SoftDeleteMixin, TimestampMixin, Base):
    """An expense repeated every interval_count periods."""

    __tablename__ = "recurring_expenses"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "client_id",
            name="uq_recurring_expenses_user_client",
        ),
        CheckConstraint(
            "period IN ('daily', 'weekly', 'monthly')",
            name="ck_recurring_expenses_period",
        ),
        CheckConstraint("amount > 0", name="ck_recurring_expenses_amount_positive"),
        CheckConstraint(
            "interval_count >= 1",
            name="ck_recurring_expenses_interval",
        ),
        Index(
            "ix_recurring_expenses_due",
            "is_active",
            "next_run_at",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )

    amount: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    currency_code: Mapped[str] = mapped_column(
        String(10),
        default="SYP",
        nullable=False,
    )
    category: Mapped[str] = mapped_column(Text, nullable=False)
    payment_method: Mapped[str] = mapped_column(
        Text,
        default="",
        nullable=False,
    )
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    period: Mapped[str] = mapped_column(String(20), nullable=False)
    interval_count: Mapped[int] = mapped_column(default=1, nullable=False)
    next_run_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        index=True,
    )
    requires_confirmation: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    remind_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    remind_on_income: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    user: Mapped["User"] = relationship(back_populates="recurring_expenses")
