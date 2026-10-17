"""Custom expense categories the user adds next to the built-in ones."""

from sqlalchemy import ForeignKey, Index, Integer, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base, ClientIdMixin, SoftDeleteMixin, TimestampMixin


class ExpenseCategory(ClientIdMixin, SoftDeleteMixin, TimestampMixin, Base):
    """A category the user created, with its label and icon."""

    __tablename__ = "expense_categories"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "client_id",
            name="uq_expense_categories_user_client",
        ),
        Index("ix_expense_categories_user_updated", "user_id", "updated_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    label: Mapped[str] = mapped_column(Text, nullable=False)
    icon_index: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    user: Mapped["User"] = relationship(back_populates="expense_categories")
