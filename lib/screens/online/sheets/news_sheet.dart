// Full news list sheet opened from the online preview card.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/containers/app_empty_state.dart';
import 'package:waffr/data/models/news_article.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Opens the full news list for [articles] in a tall glass sheet.
Future<void> showNewsSheet(
  BuildContext context, {
  required List<NewsArticle> articles,
}) {
  return showGlassSheet<void>(
    context: context,
    heightFactor: 0.85,
    builder: (context) => _NewsSheet(articles: articles),
  );
}

/// Scrollable list of headlines with source and timestamp, or an empty
/// state when there are no articles.
class _NewsSheet extends StatelessWidget {
  final List<NewsArticle> articles;

  const _NewsSheet({required this.articles});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;

    return GlassSheetFixedBody(
      header: const GlassSheetHeader(
        title: 'الأخبار',
        subtitle: 'آخر العناوين',
      ),
      body: articles.isEmpty
          ? const AppEmptyState(
              icon: Icons.newspaper_outlined,
              title: 'لا توجد أخبار حالياً',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: articles.length,
              separatorBuilder: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: textSecondary.withValues(alpha: 0.22),
                ),
              ),
              itemBuilder: (context, index) {
                return _NewsArticleBlock(
                  article: articles[index],
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                );
              },
            ),
    );
  }
}

/// Title, optional body, then source and published time for one article in
/// the sheet.
class _NewsArticleBlock extends StatelessWidget {
  final NewsArticle article;
  final Color textPrimary;
  final Color textSecondary;

  const _NewsArticleBlock({
    required this.article,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          article.title,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontFamilyFallback: ['Tajawal'],
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            height: 1.45,
          ),
        ),
        if (article.body.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            article.body,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: textPrimary.withValues(alpha: 0.82),
              height: 1.65,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          '${article.source} · ${formatDate(article.publishedAt)} · ${formatTime(article.publishedAt)}',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontFamilyFallback: ['Tajawal'],
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          ),
        ),
      ],
    );
  }
}
