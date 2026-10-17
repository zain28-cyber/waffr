// Smoke tests for the online tab and the news sheet. Network calls fail fast
// in tests, so the tab shows its offline / sign-in states.

import 'package:waffr/data/models/news_article.dart';
import 'package:waffr/screens/online/online_screen.dart';
import 'package:waffr/screens/online/sheets/news_sheet.dart';

import '../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen('OnlineScreen', () => const OnlineScreen());
  smokeTestScreen(
    'news sheet',
    () => SheetLauncher(
      open: (context) => showNewsSheet(
        context,
        articles: [
          NewsArticle(
            title: 'title',
            body: 'body',
            source: 'source',
            publishedAt: DateTime(2026, 3, 1),
          ),
        ],
      ),
    ),
    interact: openSheet,
    withSampleData: false,
  );
}
