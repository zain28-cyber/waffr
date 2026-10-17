"""Saved expenses the user can refill in one tap."""

from decimal import Decimal

from sqlalchemy import Boolean, ForeignKey, Index, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import MONEY, Base, ClientIdMixin, SoftDeleteMixin, TimestampMixin


class ExpensePreset(ClientIdMixin, SoftDeleteMixin, TimestampMixin, Base):
    """A saved expense the app can refill from the star on the expense sheet."""

    __tablename__ = "expense_presets"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "client_id",
            name="uq_expense_presets_user_client",
        ),
        Index("ix_expense_presets_user_updated", "user_id", "updated_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    # Amount as typed, before the multiplier.
    amount: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    multiplier: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    currency_code: Mapped[str] = mapped_column(String(10), default="SYP", nullable=False)
    # Encrypted on the device like the other private text.
    category: Mapped[str] = mapped_column(Text, nullable=False)
    payment_method: Mapped[str] = mapped_column(Text, default="", nullable=False)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    recurring: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    unit: Mapped[str] = mapped_column(String(10), default="month", nullable=False)
    interval_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    user: Mapped["User"] = relationship(back_populates="expense_presets")
