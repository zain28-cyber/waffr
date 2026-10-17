"""Savings goals and the transfers that move money into and out of them."""

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
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import (
    MONEY,
    Base,
    ClientIdMixin,
    CreatedAtMixin,
    SoftDeleteMixin,
    TimestampMixin,
    utc_now,
)


class SavingsGoal(ClientIdMixin, SoftDeleteMixin, TimestampMixin, Base):
    """A savings target, optionally with a periodic deduction plan."""

    __tablename__ = "savings_goals"
    __table_args__ = (
        UniqueConstraint("user_id", "client_id", name="uq_savings_goals_user_client"),
        CheckConstraint("target_amount > 0", name="ck_savings_goals_target_positive"),
        CheckConstraint("saved_amount >= 0", name="ck_savings_goals_saved_non_negative"),
        CheckConstraint(
            "duration IN ('week', 'month', 'threeMonths', 'sixMonths', 'year')",
            name="ck_savings_goals_duration",
        ),
        CheckConstraint(
            "deduct_frequency IN ('none', 'weekly', 'monthly')",
            name="ck_savings_goals_deduct_frequency",
        ),
        Index("ix_savings_goals_user_updated", "user_id", "updated_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )

    name: Mapped[str] = mapped_column(Text, nullable=False)
    currency_code: Mapped[str] = mapped_column(
        String(10),
        default="SYP",
        nullable=False,
    )
    target_amount: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    saved_amount: Mapped[Decimal] = mapped_column(
        MONEY,
        default=Decimal("0.00"),
        nullable=False,
    )
    deadline: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    completed_amount: Mapped[Decimal | None] = mapped_column(MONEY, nullable=True)
    duration: Mapped[str] = mapped_column(
        String(20),
        default="month",
        nullable=False,
    )
    allocate_percent: Mapped[Decimal | None] = mapped_column(
        MONEY,
        nullable=True,
    )
    allocate_amount: Mapped[Decimal | None] = mapped_column(MONEY, nullable=True)
    deduct_frequency: Mapped[str] = mapped_column(
        String(20),
        default="monthly",
        nullable=False,
    )
    is_periodic: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    duration_count: Mapped[int | None] = mapped_column(nullable=True)
    priority: Mapped[int] = mapped_column(default=0, nullable=False)
    is_completed: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        index=True,
    )

    user: Mapped["User"] = relationship(back_populates="savings_goals")
    transfers: Mapped[list["SavingsTransfer"]] = relationship(
        back_populates="goal",
        passive_deletes=True,
    )


class SavingsTransfer(ClientIdMixin, SoftDeleteMixin, CreatedAtMixin, Base):
    """Money moved to savings (to_savings) or back (to_balance)."""

    __tablename__ = "savings_transfers"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "client_id",
            name="uq_savings_transfers_user_client",
        ),
        CheckConstraint(
            "direction IN ('to_savings', 'to_balance')",
            name="ck_savings_transfers_direction",
        ),
        CheckConstraint("amount > 0", name="ck_savings_transfers_amount_positive"),
        CheckConstraint(
            "kind IS NULL OR kind IN "
            "('periodLeftover', 'goalPeriodic', 'manual', 'withdraw')",
            name="ck_savings_transfers_kind",
        ),
        Index("ix_savings_transfers_user_created", "user_id", "created_at"),
        Index("ix_savings_transfers_goal_created", "goal_id", "created_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    goal_id: Mapped[int | None] = mapped_column(
        ForeignKey("savings_goals.id", ondelete="SET NULL"),
        index=True,
        nullable=True,
    )

    amount: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    currency_code: Mapped[str] = mapped_column(
        String(10),
        default="SYP",
        nullable=False,
    )
    direction: Mapped[str] = mapped_column(String(20), nullable=False)
    kind: Mapped[str | None] = mapped_column(String(30), nullable=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )
    processed_period_key: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        onupdate=utc_now,
        nullable=False,
    )

    user: Mapped["User"] = relationship(back_populates="savings_transfers")
    goal: Mapped[SavingsGoal | None] = relationship(back_populates="transfers")
