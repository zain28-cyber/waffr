"""Shopping lists and their items."""

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

from database import MONEY, Base, ClientIdMixin, SoftDeleteMixin, TimestampMixin


class ShoppingList(ClientIdMixin, SoftDeleteMixin, TimestampMixin, Base):
    """A named shopping list."""

    __tablename__ = "shopping_lists"
    __table_args__ = (
        UniqueConstraint("user_id", "client_id", name="uq_shopping_lists_user_client"),
        Index("ix_shopping_lists_user_updated", "user_id", "updated_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)

    user: Mapped["User"] = relationship(back_populates="shopping_lists")
    items: Mapped[list["ShoppingItem"]] = relationship(
        back_populates="shopping_list",
        cascade="all, delete-orphan",
    )


class ShoppingItem(ClientIdMixin, SoftDeleteMixin, TimestampMixin, Base):
    """One item on a list, optionally linked to the expense that paid for it."""

    __tablename__ = "shopping_items"
    __table_args__ = (
        UniqueConstraint("user_id", "client_id", name="uq_shopping_items_user_client"),
        CheckConstraint("quantity >= 1", name="ck_shopping_items_quantity"),
        CheckConstraint(
            "price IS NULL OR price >= 0",
            name="ck_shopping_items_price_non_negative",
        ),
        Index("ix_shopping_items_list", "list_id", "is_purchased"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    list_id: Mapped[int] = mapped_column(
        ForeignKey("shopping_lists.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )

    name: Mapped[str] = mapped_column(Text, nullable=False)
    quantity: Mapped[int] = mapped_column(default=1, nullable=False)
    price: Mapped[Decimal | None] = mapped_column(MONEY, nullable=True)
    is_purchased: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        index=True,
    )
    purchased_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    expense_client_id: Mapped[str | None] = mapped_column(
        String(64),
        nullable=True,
    )

    shopping_list: Mapped[ShoppingList] = relationship(back_populates="items")
