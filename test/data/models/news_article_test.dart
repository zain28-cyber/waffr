// NewsArticle.fromApi: parsing a feed row, defaults for optional fields,
// and skipping rows without a title or publish time.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/news_article.dart';

void main() {
  group('NewsArticle.fromApi', () {
    test('reads a full row', () {
      final article = NewsArticle.fromApi({
        'id': 7,
        'title': '  عنوان  ',
        'summary': ' ملخص ',
        'source': 'reuters',
        'published_at': '2026-10-01T08:00:00Z',
        'url': 'https://example.com/a',
      })!;
      expect(article.id, 7);
      expect(article.title, 'عنوان');
      expect(article.body, 'ملخص');
      expect(article.source, 'reuters');
      expect(article.publishedAt, DateTime.utc(2026, 10, 1, 8));
      expect(article.url, 'https://example.com/a');
    });

    test('fills defaults for optional fields', () {
      final article = NewsArticle.fromApi({
        'id': '12',
        'title': 'x',
        'published_at': '2026-10-01',
        'url': '  ',
      })!;
      expect(article.id, 12);
      expect(article.body, '');
      expect(article.source, 'sana.sy');
      expect(article.url, isNull);

      final noId = NewsArticle.fromApi({
        'id': 'abc',
        'title': 'x',
        'published_at': '2026-10-01',
      })!;
      expect(noId.id, isNull);
    });

    test('skips rows without a title or a valid date', () {
      expect(
        NewsArticle.fromApi({'title': ' ', 'published_at': '2026-10-01'}),
        isNull,
      );
      expect(NewsArticle.fromApi({'title': 'x'}), isNull);
      expect(
        NewsArticle.fromApi({'title': 'x', 'published_at': 'yesterday'}),
        isNull,
      );
    });
  });
}
