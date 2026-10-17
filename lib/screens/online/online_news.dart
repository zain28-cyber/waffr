// Online news preview: paged headlines, page dots and the loading /
// error status.

part of 'online_screen.dart';

/// Headline teaser. Swipe up or down on the headline to move between articles
/// without leaving the tab; tap opens the full news sheet (or retries on
/// error).
class _NewsPreviewCard extends StatefulWidget {
  final List<NewsArticle> articles;
  final _NewsLoadState state;
  final VoidCallback? onTap;

  const _NewsPreviewCard({
    required this.articles,
    required this.state,
    required this.onTap,
  });

  @override
  State<_NewsPreviewCard> createState() => _NewsPreviewCardState();
}

/// State of [_NewsPreviewCard]. Owns the vertical headline pager and keeps
/// the current index inside the article list when the list shrinks.
class _NewsPreviewCardState extends State<_NewsPreviewCard> {
  /// Title (3 lines) plus the source row.
  static const double _pageHeight = 108;

  final PageController _pages = PageController();

  /// Current headline, shown as "n / count" in the header row.
  int _index = 0;

  @override
  void didUpdateWidget(covariant _NewsPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final count = widget.articles.length;
    if (count == 0) {
      _index = 0;
    } else if (_index >= count) {
      _index = count - 1;
      if (_pages.hasClients) _pages.jumpToPage(_index);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// At the first or last article, the drag keeps scrolling the tab instead.
  bool _forwardOverscroll(OverscrollNotification notification) {
    if (notification.dragDetails == null) return false;
    final outer = Scrollable.maybeOf(context)?.position;
    if (outer == null) return false;
    final target = (outer.pixels + notification.overscroll).clamp(
      outer.minScrollExtent,
      outer.maxScrollExtent,
    );
    if (target != outer.pixels) outer.jumpTo(target);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final ready =
        widget.state == _NewsLoadState.ready && widget.articles.isNotEmpty;
    final count = widget.articles.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(28),
        child: GlassContainer(
          colorType: GlassColorType.surface,
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row: title, page counter, and the sheet chevron.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'الأخبار',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: ['Tajawal'],
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (ready && count > 1)
                    AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.fast),
                      child: Text(
                        '${_index + 1} / $count',
                        key: ValueKey(_index),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: ['Tajawal'],
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: colors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 17),
              // Loading, the headline pager and the empty/error copy have
              // different heights; grow and shrink between them smoothly.
              AnimatedSize(
                duration: AppMotion.sizeOf(context, AppMotion.medium),
                curve: AppMotion.enter,
                alignment: Alignment.topCenter,
                child: ready
                    ? SizedBox(
                        height: _pageHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child:
                                  NotificationListener<OverscrollNotification>(
                                    onNotification: _forwardOverscroll,
                                    child: PageView.builder(
                                      controller: _pages,
                                      scrollDirection: Axis.vertical,
                                      physics: const PageScrollPhysics(
                                        parent: ClampingScrollPhysics(),
                                      ),
                                      itemCount: count,
                                      onPageChanged: (index) =>
                                          setState(() => _index = index),
                                      itemBuilder: (context, index) =>
                                          _NewsHeadline(
                                            article: widget.articles[index],
                                            colors: colors,
                                          ),
                                    ),
                                  ),
                            ),
                            if (count > 1) ...[
                              const SizedBox(width: 10),
                              _NewsPageDots(
                                controller: _pages,
                                count: count,
                                activeColor: colors.accent,
                                inactiveColor: colors.textSecondary.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : _NewsStatus(state: widget.state, colors: colors),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One article in the swipeable preview: title, source and time.
class _NewsHeadline extends StatelessWidget {
  final NewsArticle article;
  final AppPalette colors;

  const _NewsHeadline({required this.article, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Text(
            article.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.55,
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                article.source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${formatDate(article.publishedAt)} · ${formatTime(article.publishedAt)}',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
                fontSize: 11.5,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Vertical page marks beside the headline, like the balance-card currency
/// dots. Long feeds show a window of marks around the current article.
class _NewsPageDots extends StatelessWidget {
  /// Most marks shown at once; longer feeds slide the window.
  static const int _maxDots = 7;

  final PageController controller;
  final int count;
  final Color activeColor;
  final Color inactiveColor;

  const _NewsPageDots({
    required this.controller,
    required this.count,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = controller.hasClients
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble();
        final visible = count < _maxDots ? count : _maxDots;
        final first = (page.round() - visible ~/ 2).clamp(0, count - visible);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = first; i < first + visible; i++)
              Builder(
                builder: (context) {
                  final selected = 1 - (page - i).abs().clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Container(
                      width: 5,
                      height: 5 + 11 * selected,
                      decoration: BoxDecoration(
                        color: Color.lerp(inactiveColor, activeColor, selected),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// Loading spinner or empty/error copy inside the news preview card.
class _NewsStatus extends StatelessWidget {
  final _NewsLoadState state;
  final AppPalette colors;

  const _NewsStatus({required this.state, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (state == _NewsLoadState.loading) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: colors.accent,
          ),
        ),
      );
    }

    final message = state == _NewsLoadState.error
        ? 'تعذّر تحميل الأخبار'
        : 'لا توجد أخبار حالياً';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontFamilyFallback: ['Tajawal'],
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.55,
            color: colors.textSecondary,
          ),
        ),
        if (state == _NewsLoadState.error) ...[
          const SizedBox(height: 10),
          Text(
            'اضغط لإعادة المحاولة',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
