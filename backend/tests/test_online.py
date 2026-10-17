"""/online/news and the news service behind it.

The feeds are never fetched: ``fetch_feed`` is replaced with canned RSS, so
these tests cover filtering, storage, pruning and the routes offline.
"""

import pytest

from conftest import bearer, system_execute, system_scalar

SANA_FEED = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>SANA</title>
<item>
  <title>Exchange rate &amp; markets</title>
  <link>https://sana.sy/economy/rates-1</link>
  <guid>sana-1</guid>
  <category>اقتصاد</category>
  <description>&lt;p&gt;The pound held steady.&lt;/p&gt;</description>
  <pubDate>Sat, 01 Mar 2025 10:00:00 +0000</pubDate>
</item>
<item>
  <title>Football results</title>
  <link>https://sana.sy/sport/match-1</link>
  <guid>sana-2</guid>
  <category>رياضة</category>
  <pubDate>Sat, 01 Mar 2025 11:00:00 +0000</pubDate>
</item>
<item>
  <title>Off-site economy story</title>
  <link>https://evil.example.com/economy/x</link>
  <guid>sana-3</guid>
  <category>اقتصاد</category>
</item>
</channel></rss>"""

IKHBARIA_FEED = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Ikhbaria</title>
<item>
  <title>Budget approved</title>
  <link>https://alikhbariah.com/budget-approved/</link>
  <guid>ikh-1</guid>
  <category>اقتصاد</category>
  <description>Details. The post Budget approved appeared first on Ikhbaria.</description>
  <pubDate>Sun, 02 Mar 2025 09:00:00 +0000</pubDate>
</item>
</channel></rss>"""


@pytest.fixture
def news_feeds(monkeypatch):
    """Serve canned feeds; returns the list of sources that were fetched."""
    import news_service

    payloads = {
        news_service.SANA_SOURCE.name: SANA_FEED.encode(),
        news_service.IKHBARIA_SOURCE.name: IKHBARIA_FEED.encode(),
    }
    fetched: list[str] = []

    def fake_fetch(source):
        fetched.append(source.name)
        return payloads[source.name]

    monkeypatch.setattr(news_service, "fetch_feed", fake_fetch)
    return fetched


# Routes


def test_news_fills_an_empty_table_on_first_read(client, news_feeds):
    response = client.get("/online/news")
    assert response.status_code == 200
    articles = response.json()
    assert [a["title"] for a in articles] == ["Budget approved", "Exchange rate & markets"]
    sana = articles[1]
    assert sana["source"] == "sana.sy"
    assert sana["url"] == "https://sana.sy/economy/rates-1"
    assert sana["summary"] == "The pound held steady."
    assert articles[0]["summary"] == "Details."
    assert sorted(news_feeds) == ["alikhbariah.com", "sana.sy"]

    # Stored rows are served without fetching again.
    news_feeds.clear()
    assert len(client.get("/online/news").json()) == 2
    assert news_feeds == []


def test_news_is_public(client, news_feeds):
    assert client.get("/online/news").status_code == 200


def test_news_is_unavailable_when_every_feed_is_down_and_nothing_is_stored(client):
    # The default fake in conftest makes every feed fail.
    response = client.get("/online/news")
    assert response.status_code == 503
    assert response.json()["detail"] == "News is temporarily unavailable"


def test_stored_news_survives_a_failed_refresh(client, alice, news_feeds, monkeypatch):
    import news_service

    client.get("/online/news")

    def down(_source):
        raise news_service.NewsFeedUnavailable()

    monkeypatch.setattr(news_service, "fetch_feed", down)
    refreshed = client.post("/online/news/refresh", headers=bearer(alice)).json()
    assert refreshed["ok"] is False
    assert refreshed["error"] == "feed_unavailable"
    assert len(client.get("/online/news").json()) == 2


def test_manual_refresh_reports_counts(client, alice, news_feeds):
    response = client.post("/online/news/refresh", headers=bearer(alice))
    assert response.status_code == 200
    assert response.json() == {"ok": True, "fetched": 4, "matched": 2, "saved": 2, "error": None}
    assert system_scalar("SELECT count(*) FROM news_articles") == 2
    # A second refresh updates the same rows instead of adding more.
    client.post("/online/news/refresh", headers=bearer(alice))
    assert system_scalar("SELECT count(*) FROM news_articles") == 2


def test_manual_refresh_is_limited_per_account(client, alice, bob, news_feeds):
    statuses = [
        client.post("/online/news/refresh", headers=bearer(alice)).status_code for _ in range(3)
    ]
    assert statuses == [200, 200, 429]
    assert client.post("/online/news/refresh", headers=bearer(bob)).status_code == 200


def test_manual_refresh_needs_a_token(client):
    assert client.post("/online/news/refresh").status_code == 401


# The news service


def test_only_economy_entries_from_the_source_hosts_are_kept():
    import news_service

    fetched, articles = news_service.parse_feed(SANA_FEED.encode(), news_service.SANA_SOURCE)
    assert fetched == 3
    assert [a.guid for a in articles] == ["sana-1"]


@pytest.mark.parametrize(
    "categories, url, text, expected",
    [
        (["اقتصاد"], "https://sana.sy/x", "", True),
        ([], "https://sana.sy/economy/a", "", True),
        (["سياسة"], "https://sana.sy/x", "سعر الصرف", False),
        ([], "https://sana.sy/politics/a", "سعر الصرف", False),
        ([], "https://sana.sy/", "ارتفاع سعر الصرف اليوم", True),
        ([], "https://sana.sy/", "football", False),
    ],
)
def test_economy_filter_prefers_sections_over_keywords(categories, url, text, expected):
    import news_service

    assert (
        news_service.is_economy_entry(categories, url, text, "", news_service.SANA_SOURCE)
        is expected
    )


def test_clean_text_strips_markup_and_limits_length():
    import news_service

    assert news_service.clean_text("<b>Hello</b>‏   &amp;  world", 100) == "Hello & world"
    assert news_service.clean_text("abcdef", 3) == "abc"
    assert news_service.clean_text(None, 10) == ""


def test_published_date_must_be_plausible():
    import news_service

    assert news_service.parse_published({"published": "Sat, 01 Mar 2025 10:00:00 +0000"}).year == 2025
    assert news_service.parse_published({"published": "Mon, 01 Jan 1900 00:00:00 +0000"}) is None
    assert news_service.parse_published({"published": "not a date"}) is None
    assert news_service.parse_published({}) is None


def test_old_articles_are_pruned(client, alice, news_feeds):
    for number in range(70):
        system_execute(
            "INSERT INTO news_articles (title, source, url, guid, published_at, fetched_at) "
            "VALUES ('old', 's', :url, :guid, timestamptz '2024-01-01' - make_interval(days => :age), now())",
            url=f"https://sana.sy/economy/old-{number}",
            guid=f"old-{number}",
            age=number + 30,
        )
    client.post("/online/news/refresh", headers=bearer(alice))
    assert system_scalar("SELECT count(*) FROM news_articles") == 60
    # The newest ones stay.
    assert system_scalar("SELECT count(*) FROM news_articles WHERE guid IN ('sana-1', 'ikh-1')") == 2
    assert len(client.get("/online/news").json()) == 30
