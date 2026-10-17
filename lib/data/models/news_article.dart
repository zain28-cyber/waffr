// News items from the economic feeds API.

/// One news item from the economic feeds API.
class NewsArticle {
  /// Server id, if any.
  final int? id;

  /// Headline.
  final String title;

  /// Summary text.
  final String body;

  /// Publisher name (sana.sy when missing).
  final String source;

  /// Publication time.
  final DateTime publishedAt;

  /// Link to the full article.
  final String? url;

  /// An article.
  const NewsArticle({
    this.id,
    required this.title,
    required this.body,
    required this.source,
    required this.publishedAt,
    this.url,
  });

  /// Builds from the API payload; skips rows missing title or publish time.
  static NewsArticle? fromApi(Map<String, dynamic> json) {
    final title = (json['title'] ?? '').toString().trim();
    final published = DateTime.tryParse(
      (json['published_at'] ?? '').toString(),
    );
    if (title.isEmpty || published == null) return null;

    final source = (json['source'] ?? '').toString().trim();
    final url = (json['url'] ?? '').toString().trim();
    final idValue = json['id'];
    final id = idValue is int ? idValue : int.tryParse('$idValue');

    return NewsArticle(
      id: id,
      title: title,
      body: (json['summary'] ?? '').toString().trim(),
      source: source.isEmpty ? 'sana.sy' : source,
      publishedAt: published,
      url: url.isEmpty ? null : url,
    );
  }
}
