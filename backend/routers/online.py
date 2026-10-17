"""/online: the economic news feed and a rate-limited manual refresh."""

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from api_schemas import NewsArticleOut, NewsRefreshOut
from auth import get_current_user
from database import get_db
from models import User
from news_service import NewsFeedUnavailable, latest_articles, refresh_news
from rate_limit import NEWS_REFRESH_ALL, NEWS_REFRESH_USER, enforce

router = APIRouter(prefix="/online", tags=["online"])


@router.get("/news", response_model=list[NewsArticleOut])
def list_news(db: Session = Depends(get_db)):
    """Latest stored articles; fetches once when the table is empty."""
    try:
        return latest_articles(db)
    except NewsFeedUnavailable:
        raise HTTPException(
            status_code=503,
            detail="News is temporarily unavailable",
        ) from None


# Fetching the feeds is slow and runs hourly anyway, so a manual refresh
# needs an account and is tightly limited.
@router.post("/news/refresh", response_model=NewsRefreshOut)
def refresh_news_now(
    request: Request,
    current_user: User = Depends(get_current_user),
):
    """Fetch the feeds now. Needs an account; tightly rate limited."""
    enforce(request, f"news-refresh:user:{current_user.id}", NEWS_REFRESH_USER)
    enforce(request, "news-refresh:all", NEWS_REFRESH_ALL)
    result = refresh_news(wait=True)
    return NewsRefreshOut(
        ok=result.ok,
        fetched=result.fetched,
        matched=result.matched,
        saved=result.saved,
        error=result.error,
    )
