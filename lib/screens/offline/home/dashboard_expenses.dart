// Home recent expenses and obligations (part of dashboard.dart): a two-page
// card with a row per expense or upcoming obligation.

part of 'dashboard.dart';

/// Two pages in one card: the last expenses and the obligations. Swiping
/// switches pages; a tap opens the full screen of the visible page.
class _ExpensesAndObligationsCard extends StatefulWidget {
  // Expenses newest first, as kept by TransactionStore.
  final List<WaffrTransaction> expenses;
  // Recurring expenses in the active currency.
  final List<RecurringExpense> obligations;
  // Tighter spacing and smaller type for the half-width home layout.
  final bool compact;

  const _ExpensesAndObligationsCard({
    required this.expenses,
    required this.obligations,
    this.compact = false,
  });

  @override
  State<_ExpensesAndObligationsCard> createState() =>
      _ExpensesAndObligationsCardState();
}

/// State of [_ExpensesAndObligationsCard]. Owns the [PageController] and
/// remembers the selected page in prefs.
class _ExpensesAndObligationsCardState
    extends State<_ExpensesAndObligationsCard> {
  /// The page the user last swiped to stays selected, across restarts too.
  static const String _pageKey = 'home_expenses_card_page';

  // Index of the visible page: 0 = expenses, 1 = obligations.
  late int _page = (AppPrefs.cached?.getInt(_pageKey) ?? 0).clamp(0, 1);
  late final PageController _controller = PageController(initialPage: _page);

  /// Records the new page and saves it for the next launch.
  void _onPageChanged(int index) {
    _page = index;
    AppPrefs.instance.then((prefs) => prefs.setInt(_pageKey, index));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opens the full expense history or the obligations sheet, matching the
  /// visible page.
  void _open() {
    if (_page == 0) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const TransactionHistoryScreen.expenses(),
        ),
      );
    } else {
      showObligationsSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = palette.accent;
    final textPrimary = palette.textPrimary;
    final compact = widget.compact;

    // Built twice: once to size the card, once inside the PageView.
    List<Widget> pages() => [
      _RecentExpensesPage(expenses: widget.expenses, compact: compact),
      _ObligationsPage(obligations: widget.obligations, compact: compact),
    ];

    return _SectionCard(
      onTap: _open,
      compact: compact,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The hidden stack sizes the card to the taller page, so swiping
          // never changes the card's height.
          Stack(
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                // Never painted: its tickers stay off so the hidden copy's
                // entrance animations do not run in the background.
                child: TickerMode(
                  enabled: false,
                  child: IndexedStack(children: pages()),
                ),
              ),
              Positioned.fill(
                // Swallows horizontal scroll notifications so the shell's tab
                // PageView does not also react to this card's swipe.
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    return notification.metrics.axis == Axis.horizontal;
                  },
                  child: PageView(
                    controller: _controller,
                    physics: const PageScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    onPageChanged: _onPageChanged,
                    children: pages(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          _PageDots(
            controller: _controller,
            count: 2,
            activeColor: accent,
            inactiveColor: textPrimary.withValues(alpha: 0.22),
          ),
        ],
      ),
    );
  }
}

/// Last three expenses from the store.
class _RecentExpensesPage extends StatelessWidget {
  final List<WaffrTransaction> expenses;
  final bool compact;

  const _RecentExpensesPage({required this.expenses, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final textPrimary = palette.textPrimary;

    final latest = expenses.take(3).toList();

    return _CardPage(
      title: 'آخر المصروفات',
      compact: compact,
      child: latest.isEmpty
          ? _EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'لا يوجد مصروف مسجّل بعد',
              compact: compact,
            )
          : Column(
              children: [
                for (int index = 0; index < latest.length; index++) ...[
                  if (index > 0)
                    Divider(
                      height: compact ? 11 : 16,
                      thickness: 1,
                      color: textPrimary.withValues(alpha: 0.08),
                    ),
                  // Keyed by id so only a newly added expense plays the
                  // entrance; rows already shown keep their state.
                  Reveal(
                    key: ValueKey(latest[index].id),
                    index: index,
                    child: _ExpenseRow(
                      expense: latest[index],
                      compact: compact,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Up to three obligations: those waiting for the user first, then the
/// nearest charge dates.
class _ObligationsPage extends StatelessWidget {
  final List<RecurringExpense> obligations;
  final bool compact;

  const _ObligationsPage({required this.obligations, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final textPrimary = palette.textPrimary;

    final now = deviceNow();
    final active = obligations.where((item) => item.enabled).toList()
      ..sort((a, b) {
        final aFirst = obligationNeedsAttention(a, now: now) ? 0 : 1;
        final bFirst = obligationNeedsAttention(b, now: now) ? 0 : 1;
        if (aFirst != bFirst) return aFirst.compareTo(bFirst);
        return a.nextDueAt.compareTo(b.nextDueAt);
      });
    final shown = active.take(3).toList();

    return _CardPage(
      title: 'الالتزامات',
      compact: compact,
      child: shown.isEmpty
          ? _EmptyState(
              icon: Icons.event_repeat_outlined,
              message: 'لا توجد التزامات بعد',
              compact: compact,
            )
          : Column(
              children: [
                for (int index = 0; index < shown.length; index++) ...[
                  if (index > 0)
                    Divider(
                      height: compact ? 11 : 16,
                      thickness: 1,
                      color: textPrimary.withValues(alpha: 0.08),
                    ),
                  _ObligationRow(
                    item: shown[index],
                    now: now,
                    compact: compact,
                  ),
                ],
              ],
            ),
    );
  }
}

/// Title plus body, laid out like [_SectionCard] for pages inside a card.
class _CardPage extends StatelessWidget {
  final String title;
  final Widget child;
  final bool compact;

  const _CardPage({
    required this.title,
    required this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionTitle(title: title, compact: compact),
        SizedBox(height: compact ? 14 : 16),
        child,
      ],
    );
  }
}

/// One expense: category icon, label, optional note, date/time and amount.
class _ExpenseRow extends StatelessWidget {
  final WaffrTransaction expense;
  final bool compact;

  const _ExpenseRow({required this.expense, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final accent = palette.accent;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;

    final category = categoryFor(expense.category);
    final note = expense.note;

    // Built once, then placed either scaled-to-fit (compact) or padded.
    final amount = Text(
      '${formatMoney(expense.amount)} $currencyLabel',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontFamilyFallback: ['Tajawal'],
        fontSize: compact ? 11.5 : 14,
        fontWeight: FontWeight.bold,
        color: accent,
      ),
    );

    final iconSize = compact ? 26.0 : 44.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category icon bubble.
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.12),
          ),
          child: Icon(category.icon, size: compact ? 14 : 21, color: accent),
        ),
        SizedBox(width: compact ? 6 : 12),
        // Category label, note and timestamp.
        Expanded(
          flex: compact ? 6 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: compact ? 12.5 : 15.5,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              if (note != null && note.isNotEmpty) ...[
                SizedBox(height: compact ? 1 : 2),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                    fontSize: compact ? 10.5 : 12.5,
                    color: textSecondary,
                  ),
                ),
              ],
              SizedBox(height: compact ? 1 : 3),
              Text(
                '${formatDate(expense.dateTime)} • ${formatTime(expense.dateTime)}',
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: compact ? 9 : 11,
                  color: textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: compact ? 4 : 8),
        if (compact)
          Expanded(
            flex: 5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: amount,
            ),
          )
        else
          Padding(padding: const EdgeInsets.only(top: 2), child: amount),
      ],
    );
  }
}

/// One obligation, styled like [_ExpenseRow]. The status line turns to the
/// warning colour when the obligation needs the user's attention.
class _ObligationRow extends StatelessWidget {
  final RecurringExpense item;
  final DateTime now;
  final bool compact;

  const _ObligationRow({
    required this.item,
    required this.now,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final accent = palette.accent;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;
    final warning = AppColors.warningOf(context);

    final category = categoryFor(item.category);
    final attention = obligationNeedsAttention(item, now: now);
    final iconSize = compact ? 26.0 : 44.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category icon bubble.
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.12),
          ),
          child: Icon(category.icon, size: compact ? 14 : 21, color: accent),
        ),
        SizedBox(width: compact ? 6 : 12),
        // Title and due/attention status.
        Expanded(
          flex: compact ? 6 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                obligationTitle(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: compact ? 12.5 : 15.5,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              SizedBox(height: compact ? 1 : 2),
              Text(
                obligationStatus(item, now: now, short: compact),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: compact ? 10.5 : 12.5,
                  fontWeight: attention ? FontWeight.w700 : FontWeight.w400,
                  color: attention ? warning : textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: compact ? 4 : 8),
        // Amount in the obligation's own currency.
        Expanded(
          flex: compact ? 5 : 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              '${formatMoney(item.amount)} ${currencyLabelFor(item.currencyCode)}',
              maxLines: 1,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
                fontSize: compact ? 11.5 : 14,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
