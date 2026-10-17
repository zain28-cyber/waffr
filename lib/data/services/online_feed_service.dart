// Data for the online tab: the exchange-rate rows and the news feed.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waffr/data/models/currency.dart';
import 'package:waffr/data/models/exchange_rate.dart';
import 'package:waffr/data/models/news_article.dart';
import 'package:waffr/core/sync/api_config.dart';

/// Online feed helpers: hardcoded exchange rates plus news from the API.
class OnlineFeedService {
  OnlineFeedService._();

  /// The app-wide service.
  static final OnlineFeedService instance = OnlineFeedService._();

  static const Duration _timeout = Duration(seconds: 25);

  /// Every catalog currency except SYP, plus 21k gold. Quotes are a minus
  /// until a live feed replaces these placeholders.
  static final List<ExchangeRate> rates = [
    for (final item in Currencies.catalog)
      if (item.code != defaultCurrencyCode)
        ExchangeRate(
          code: item.code,
          chipLabel: item.symbol,
          pairLabel: item.arabicName,
        ),
    const ExchangeRate(
      code: 'GOLD21',
      chipLabel: 'ذهب',
      pairLabel: 'ذهب عيار 21',
    ),
  ];

  /// The rate row for [code] (must be one of [rates]).
  static ExchangeRate rateFor(String code) {
    return rates.firstWhere((rate) => rate.code == code);
  }

  /// GET `/online/news` and parse each map into a [NewsArticle].
  Future<List<NewsArticle>> fetchArticles() async {
    final base = await ApiConfig.baseUrl();
    final response = await http
        .get(
          Uri.parse('$base/online/news'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(ApiConfig.timeoutFor(base, local: _timeout));

    if (response.statusCode != 200) {
      throw Exception('news ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('news payload');
    }

    final articles = <NewsArticle>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final article = NewsArticle.fromApi(Map<String, dynamic>.from(item));
      if (article != null) articles.add(article);
    }
    return articles;
  }
}
