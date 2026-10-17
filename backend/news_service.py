"""Fetch, filter, and store economic news from official RSS feeds.

SANA publishes one general feed. Section metadata is preferred over keyword
matching:

* RSS ``category`` terms such as ``اقتصاد`` and ``اقتصاد سوريا``
* the article permalink section, such as ``/economy/``

Al-Ikhbariya publishes an economy category feed. Entries still have to carry
the ``اقتصاد`` category. The site-wide feed and the comments feed are ignored.

``ECONOMY_KEYWORDS`` is used only when an entry has neither category tags nor
a permalink section.
"""

from __future__ import annotations

import asyncio
import calendar
import html
import logging
import re
import threading
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from urllib.parse import urlparse

import feedparser
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from database import SessionLocal, utc_now
from online_model import NewsArticle
from row_security import bind_system

logger = logging.getLogger("waffr.news")

FEED_TIMEOUT_SECONDS = 30
FEED_ATTEMPTS = 3
FEED_RETRY_DELAY_SECONDS = 2
MAX_FEED_BYTES = 2_000_000
NEWS_LIST_LIMIT = 30
# Rows kept in the table. Older articles are deleted after each refresh so
# the store does not grow forever.
NEWS_KEEP_LIMIT = 60
NEWS_REFRESH_INTERVAL_SECONDS = 60 * 60
TITLE_LIMIT = 500
URL_LIMIT = 1000
GUID_LIMIT = 1000
SUMMARY_LIMIT = 4000

# Explicit SANA section names seen on the general RSS feed.
SANA_ECONOMY_CATEGORIES = frozenset({"اقتصاد", "اقتصاد سوريا"})

# First permalink segment for the SANA economy desk, including child sections
# such as /economy/syrian-economy/.
SANA_ECONOMY_SECTION_SLUGS = frozenset({"economy"})

# Al-Ikhbariya economy desk. Permalinks are post slugs, so the category is
# the only section signal.
IKHBARIA_ECONOMY_CATEGORIES = frozenset({"اقتصاد"})

# Fallback only. Edit this tuple when category metadata is missing.
ECONOMY_KEYWORDS = (
    "اقتصاد",
    "مالي",
    "مالية",
    "مصرف",
    "سعر الصرف",
    "الليرة السورية",
    "التضخم",
    "ميزانية",
    "ضريبة",
    "البورصة",
    "استثمار",
    "جمارك",
    "النفط",
    "رواتب",
)

_TAG_RE = re.compile(r"<[^>]*>")
_WS_RE = re.compile(r"\s+")
_BIDI_RE = re.compile(
    r"[\u00ad\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff\u0640]"
)
_refresh_lock = threading.Lock()


class NewsFeedUnavailable(Exception):
    """The upstream feed could not be fetched or parsed."""


@dataclass(frozen=True)
class NewsSource:
    """One RSS feed and the hosts and sections that count as economy news."""

    name: str
    feed_url: str
    allowed_hosts: frozenset[str]
    economy_categories: frozenset[str]
    economy_section_slugs: frozenset[str]


SANA_SOURCE = NewsSource(
    name="sana.sy",
    feed_url="https://sana.sy/feed/",
    allowed_hosts=frozenset({"sana.sy", "www.sana.sy"}),
    economy_categories=SANA_ECONOMY_CATEGORIES,
    economy_section_slugs=SANA_ECONOMY_SECTION_SLUGS,
)
IKHBARIA_SOURCE = NewsSource(
    name="alikhbariah.com",
    feed_url="https://alikhbariah.com/category/%D8%A7%D9%82%D8%AA%D8%B5%D8%A7%D8%AF/feed/",
    allowed_hosts=frozenset({"alikhbariah.com", "www.alikhbariah.com"}),
    economy_categories=IKHBARIA_ECONOMY_CATEGORIES,
    economy_section_slugs=frozenset(),
)
NEWS_SOURCES = (SANA_SOURCE, IKHBARIA_SOURCE)

# WordPress appends this sentence to excerpts on alikhbariah.com.
_WP_CREDIT_RE = re.compile(
    r"\s*The post .+ appeared first on .+\s*$",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class NewsRefreshResult:
    """What a refresh fetched, kept and saved, or why it failed."""

    ok: bool
    fetched: int = 0
    matched: int = 0
    saved: int = 0
    error: str | None = None


@dataclass(frozen=True)
class NormalizedArticle:
    """A feed entry cleaned and checked, ready to store."""

    title: str
    url: str
    guid: str
    summary: str | None
    published_at: datetime | None
    source: str


_last_result = NewsRefreshResult(ok=False, error="not_run")


def clean_text(value: object, limit: int) -> str:
    """Plain text from feed HTML: entities decoded, tags and bidi marks removed."""
    if value is None:
        return ""
    text = html.unescape(str(value))
    text = _TAG_RE.sub(" ", text)
    text = _BIDI_RE.sub("", text)
    text = _WS_RE.sub(" ", text).strip()
    if len(text) > limit:
        return text[:limit].rstrip()
    return text


def _normalize(value: object) -> str:
    return clean_text(value, 300).casefold()


_ECONOMY_KEYWORD_KEYS = tuple(_normalize(keyword) for keyword in ECONOMY_KEYWORDS)


def section_slug(url: str) -> str:
    """First path segment of [url], lower-cased."""
    path = urlparse(url).path.strip("/")
    if not path:
        return ""
    return path.split("/", 1)[0].casefold()


def is_economy_entry(
    categories: list[str],
    url: str,
    title: str,
    summary: str,
    source: NewsSource,
) -> bool:
    """Keep an entry when the source marks it as economy.

    Category terms and the permalink section win. Keywords are consulted only
    when both of those signals are absent, so a political story that merely
    mentions money is not treated as economic news.
    """
    category_keys = frozenset(_normalize(name) for name in source.economy_categories)
    category_set = {_normalize(name) for name in categories if name}
    if category_set & category_keys:
        return True
    section = section_slug(url)
    if section in source.economy_section_slugs:
        return True
    if category_set or section:
        return False
    haystack = _normalize(f"{title} {summary}")
    return any(keyword and keyword in haystack for keyword in _ECONOMY_KEYWORD_KEYS)


def parse_published(entry: dict) -> datetime | None:
    """The entry's publish time in UTC, or None when missing or implausible."""
    parsed = entry.get("published_parsed") or entry.get("updated_parsed")
    if parsed:
        try:
            published = datetime.fromtimestamp(calendar.timegm(parsed), tz=timezone.utc)
        except (OverflowError, OSError, TypeError, ValueError):
            published = None
        else:
            if _plausible_year(published):
                return published

    raw = entry.get("published") or entry.get("updated") or ""
    if not raw:
        return None
    try:
        published = parsedate_to_datetime(str(raw))
    except (IndexError, OverflowError, TypeError, ValueError):
        return None
    if published.tzinfo is None:
        published = published.replace(tzinfo=timezone.utc)
    else:
        published = published.astimezone(timezone.utc)
    if not _plausible_year(published):
        return None
    return published


def _plausible_year(value: datetime) -> bool:
    year = value.year
    current = datetime.now(timezone.utc).year
    return 1990 <= year <= current + 1


def _entry_categories(entry: dict) -> list[str]:
    names: list[str] = []
    for tag in entry.get("tags") or []:
        term = ""
        if isinstance(tag, dict):
            term = tag.get("term") or tag.get("label") or ""
        else:
            term = getattr(tag, "term", "") or ""
        cleaned = _normalize(term)
        if cleaned:
            names.append(cleaned)
    return names


def _clean_url(value: object, allowed_hosts: frozenset[str]) -> str:
    text = html.unescape(str(value or "")).strip()
    text = _BIDI_RE.sub("", text)
    text = _WS_RE.sub("", text)
    if not text or len(text) > URL_LIMIT:
        return ""
    parsed = urlparse(text)
    host = (parsed.hostname or "").lower()
    if parsed.scheme not in {"http", "https"} or host not in allowed_hosts:
        return ""
    return text


def _clean_guid(value: object, fallback_url: str) -> str:
    text = clean_text(value, GUID_LIMIT + 1)
    if not text:
        text = fallback_url
    if not text or len(text) > GUID_LIMIT:
        return ""
    return text


def _entry_summary(entry: dict) -> str:
    summary = clean_text(entry.get("summary"), SUMMARY_LIMIT)
    if not summary:
        content = entry.get("content") or []
        if isinstance(content, list) and content:
            first = content[0]
            raw = first.get("value") if isinstance(first, dict) else ""
            summary = clean_text(raw, SUMMARY_LIMIT)
    summary = _WP_CREDIT_RE.sub("", summary).strip()
    if len(summary) > SUMMARY_LIMIT:
        return summary[:SUMMARY_LIMIT].rstrip()
    return summary


def normalize_entry(entry: dict, source: NewsSource) -> NormalizedArticle | None:
    """A storable article from a feed entry, or None to skip it."""
    url = _clean_url(entry.get("link"), source.allowed_hosts)
    title = clean_text(entry.get("title"), TITLE_LIMIT)
    if not url or not title:
        return None
    guid = _clean_guid(entry.get("id") or entry.get("guid"), url)
    if not guid:
        return None
    summary = _entry_summary(entry)
    categories = _entry_categories(entry)
    if not is_economy_entry(categories, url, title, summary, source):
        return None
    return NormalizedArticle(
        title=title,
        url=url,
        guid=guid,
        summary=summary or None,
        published_at=parse_published(entry),
        source=source.name,
    )


def parse_feed(payload: bytes, source: NewsSource) -> tuple[int, list[NormalizedArticle]]:
    """(entries in the feed, economy articles kept) for one payload."""
    parsed = feedparser.parse(payload)
    entries = list(getattr(parsed, "entries", None) or [])
    if not entries and getattr(parsed, "bozo", False):
        raise NewsFeedUnavailable()
    articles: list[NormalizedArticle] = []
    seen: set[str] = set()
    for entry in entries:
        article = normalize_entry(entry, source)
        if article is None or article.guid in seen or article.url in seen:
            continue
        seen.add(article.guid)
        seen.add(article.url)
        articles.append(article)
    return len(entries), articles


def _feed_request(source: NewsSource) -> urllib.request.Request:
    return urllib.request.Request(
        source.feed_url,
        headers={
            "User-Agent": "Waffr/1.0",
            "Accept": "application/rss+xml, application/xml, text/xml;q=0.9, */*;q=0.8",
        },
    )


def _request_failure_detail(exc: BaseException) -> str:
    reason = getattr(exc, "reason", None)
    if reason is None:
        return str(exc) or type(exc).__name__
    return f"{type(reason).__name__}: {reason}"


class _SourceRedirects(urllib.request.HTTPRedirectHandler):
    """Follow redirects only to the source's own HTTPS hosts.

    Without this a compromised feed could bounce the server's request to an
    internal address before the host check below runs.
    """

    def __init__(self, allowed_hosts: frozenset[str]):
        super().__init__()
        self._allowed_hosts = allowed_hosts

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        """Follow the redirect only to an allowed HTTPS host."""
        target = urlparse(newurl)
        host = (target.hostname or "").lower()
        if target.scheme != "https" or host not in self._allowed_hosts:
            raise NewsFeedUnavailable()
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch_feed(source: NewsSource) -> bytes:
    """Download one feed, with retries; NewsFeedUnavailable on failure."""
    last_error: Exception | None = None
    opener = urllib.request.build_opener(_SourceRedirects(source.allowed_hosts))
    for attempt in range(1, FEED_ATTEMPTS + 1):
        try:
            with opener.open(
                _feed_request(source),
                timeout=FEED_TIMEOUT_SECONDS,
            ) as response:
                final_host = (urlparse(response.geturl()).hostname or "").lower()
                if final_host not in source.allowed_hosts:
                    raise NewsFeedUnavailable()
                payload = response.read(MAX_FEED_BYTES + 1)
        except NewsFeedUnavailable:
            raise
        except (TimeoutError, urllib.error.URLError, OSError) as exc:
            last_error = exc
            logger.warning(
                "%s feed request failed (attempt %s/%s): %s",
                source.name,
                attempt,
                FEED_ATTEMPTS,
                _request_failure_detail(exc),
            )
            if attempt < FEED_ATTEMPTS:
                time.sleep(FEED_RETRY_DELAY_SECONDS)
            continue
        if not payload or len(payload) > MAX_FEED_BYTES:
            raise NewsFeedUnavailable()
        return payload
    raise NewsFeedUnavailable() from last_error


def _query_latest(db: Session, limit: int) -> list[NewsArticle]:
    return (
        db.query(NewsArticle)
        .order_by(NewsArticle.published_at.desc(), NewsArticle.id.desc())
        .limit(limit)
        .all()
    )


def _taken(db: Session, column, value: str, row_id: int) -> bool:
    return (
        db.query(NewsArticle.id)
        .filter(column == value, NewsArticle.id != row_id)
        .first()
        is not None
    )


def _upsert(db: Session, article: NormalizedArticle, fetched_at: datetime) -> None:
    matches = (
        db.query(NewsArticle)
        .filter((NewsArticle.guid == article.guid) | (NewsArticle.url == article.url))
        .all()
    )
    existing = next((row for row in matches if row.guid == article.guid), None)
    if existing is None and matches:
        existing = matches[0]

    published_at = article.published_at
    if existing is None:
        db.add(
            NewsArticle(
                title=article.title,
                source=article.source,
                url=article.url,
                guid=article.guid,
                summary=article.summary,
                published_at=published_at or fetched_at,
                fetched_at=fetched_at,
            )
        )
        return

    existing.title = article.title
    existing.source = article.source
    existing.summary = article.summary
    existing.fetched_at = fetched_at
    if published_at is not None:
        existing.published_at = published_at
    if existing.guid != article.guid and not _taken(db, NewsArticle.guid, article.guid, existing.id):
        existing.guid = article.guid
    if existing.url != article.url and not _taken(db, NewsArticle.url, article.url, existing.id):
        existing.url = article.url


def _store_articles(db: Session, articles: list[NormalizedArticle]) -> int:
    fetched_at = utc_now()
    saved = 0
    for article in articles:
        try:
            with db.begin_nested():
                _upsert(db, article, fetched_at)
            saved += 1
        except IntegrityError:
            logger.warning("skipped news row that conflicted with an existing article")
    db.flush()
    pruned = _prune_old(db, NEWS_KEEP_LIMIT)
    db.commit()
    if pruned:
        logger.info("deleted %s old news articles", pruned)
    return saved


def _prune_old(db: Session, keep: int) -> int:
    """Delete everything past the newest [keep] articles."""
    keep_ids = [
        row_id
        for (row_id,) in db.query(NewsArticle.id)
        .order_by(NewsArticle.published_at.desc(), NewsArticle.id.desc())
        .limit(keep)
        .all()
    ]
    if len(keep_ids) < keep:
        return 0
    return (
        db.query(NewsArticle)
        .filter(NewsArticle.id.notin_(keep_ids))
        .delete(synchronize_session=False)
    )


def _collect_articles() -> tuple[int, list[NormalizedArticle], int]:
    fetched = 0
    articles: list[NormalizedArticle] = []
    failures = 0
    seen: set[str] = set()
    for source in NEWS_SOURCES:
        try:
            payload = fetch_feed(source)
            count, parsed = parse_feed(payload, source)
        except NewsFeedUnavailable:
            failures += 1
            logger.warning(
                "%s feed unavailable; previously stored news was kept",
                source.name,
            )
            continue
        fetched += count
        for article in parsed:
            if article.guid in seen or article.url in seen:
                continue
            seen.add(article.guid)
            seen.add(article.url)
            articles.append(article)
        logger.info(
            "%s matched %s economic articles from %s feed entries",
            source.name,
            len(parsed),
            count,
        )
    return fetched, articles, failures


def _refresh_unlocked() -> NewsRefreshResult:
    fetched, articles, failures = _collect_articles()
    if failures == len(NEWS_SOURCES):
        return NewsRefreshResult(ok=False, error="feed_unavailable")

    db = SessionLocal()
    bind_system(db)
    try:
        saved = _store_articles(db, articles)
    except Exception:
        db.rollback()
        logger.exception("failed to store news; previously stored news was kept")
        return NewsRefreshResult(
            ok=False,
            fetched=fetched,
            matched=len(articles),
            error="store_failed",
        )
    finally:
        db.close()

    logger.info(
        "news refresh stored %s economic articles from %s feed entries",
        saved,
        fetched,
    )
    return NewsRefreshResult(
        ok=True,
        fetched=fetched,
        matched=len(articles),
        saved=saved,
    )


def refresh_news(*, wait: bool = True) -> NewsRefreshResult:
    """Fetch each RSS feed and upsert economic articles.

    A failed fetch leaves existing rows in place. One unavailable source does
    not drop articles already collected from the others. Overlapping calls
    share one refresh so repeated triggers do not insert duplicates.
    """
    global _last_result
    acquired = _refresh_lock.acquire(blocking=False)
    if not acquired:
        if not wait:
            return _last_result
        _refresh_lock.acquire()
        _refresh_lock.release()
        return _last_result

    try:
        _last_result = _refresh_unlocked()
        return _last_result
    except Exception:
        logger.exception("news refresh failed; previously stored news was kept")
        _last_result = NewsRefreshResult(ok=False, error="feed_unavailable")
        return _last_result
    finally:
        _refresh_lock.release()


def latest_articles(db: Session, limit: int = NEWS_LIST_LIMIT) -> list[NewsArticle]:
    """Return stored articles, filling the table once when it is empty."""
    bounded = max(1, min(limit, NEWS_LIST_LIMIT))
    existing = db.query(NewsArticle.id).limit(1).first()
    if existing is not None:
        return _query_latest(db, bounded)

    db.rollback()
    result = refresh_news(wait=True)
    rows = _query_latest(db, bounded)
    if not rows and not result.ok:
        raise NewsFeedUnavailable()
    return rows


async def news_refresh_loop() -> None:
    """Hourly refresh. There is no other scheduler in this project."""
    while True:
        await asyncio.to_thread(refresh_news, wait=False)
        await asyncio.sleep(NEWS_REFRESH_INTERVAL_SECONDS)
