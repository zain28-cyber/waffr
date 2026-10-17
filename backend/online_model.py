"""Shared feed data: news articles and exchange rate snapshots.

Anyone may read these tables; only the server writes them.
"""

from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, Index, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from database import RATE, Base, utc_now


class NewsArticle(Base):
    """One economic news article from an official feed."""

    __tablename__ = "news_articles"
    __table_args__ = (
        UniqueConstraint("guid", name="uq_news_articles_guid"),
        UniqueConstraint("url", name="uq_news_articles_url"),
        Index("ix_news_articles_published_at", "published_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    source: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    url: Mapped[str] = mapped_column(String(1000), nullable=False)
    guid: Mapped[str] = mapped_column(String(1000), nullable=False)
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    published_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    fetched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )


class ExchangeRate(Base):
    """A buy/sell rate snapshot for one currency from one source."""

    __tablename__ = "exchange_rates"
    __table_args__ = (
        UniqueConstraint(
            "currency",
            "source",
            "fetched_at",
            name="uq_exchange_rates_snapshot",
        ),
        Index("ix_exchange_rates_currency_fetched", "currency", "fetched_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    currency: Mapped[str] = mapped_column(String(10), nullable=False, index=True)
    buy_rate: Mapped[Decimal] = mapped_column(RATE, nullable=False)
    sell_rate: Mapped[Decimal] = mapped_column(RATE, nullable=False)
    source: Mapped[str] = mapped_column(String(100), nullable=False)
    fetched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
        index=True,
    )
