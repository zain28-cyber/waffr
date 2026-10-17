// Transaction history (part of reportscreen.dart): the expense or income
// ledger grouped by day, with per-row undo and, for expenses, multi-select
// sharing as PDF or text.

part of 'reportscreen.dart';

/// Full expense or income ledger grouped by day, with undo actions per row.
class TransactionHistoryScreen extends StatefulWidget {
  /// True for the income ledger; false for expenses.
  final bool isIncome;

  /// A [TransactionHistoryScreen] (expenses).
  const TransactionHistoryScreen.expenses({super.key}) : isIncome = false;

  /// A [TransactionHistoryScreen] (incomes).
  const TransactionHistoryScreen.incomes({super.key}) : isIncome = true;

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

/// State of [TransactionHistoryScreen]. Owns the selection-mode animation
/// controller and the set of selected transaction ids.
class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  /// Rows animate in only while the screen first opens; rows that scroll
  /// back into view later appear at rest instead of replaying the entrance.
  final Stopwatch _sinceOpened = Stopwatch()..start();
  bool get _playEntrance => _sinceOpened.elapsedMilliseconds < 700;

  final TransactionStore _store = TransactionStore.instance;
  // Stores whose changes rebuild the list.
  late final Listenable _listenables = Listenable.merge([
    _store,
    CategoryStore.instance,
    RecurringExpenseStore.instance,
  ]);

  // Selection mode flag; cleared only once the exit animation finishes.
  bool _selecting = false;
  // Ids of the selected transactions.
  final Set<String> _selected = <String>{};
  // True while a share is being built, to block a second tap.
  bool _sharing = false;
  // Drives the selection bar and row marks in and out.
  late final AnimationController _selectionAnim;
  late final CurvedAnimation _selectionReveal;

  @override
  void initState() {
    super.initState();
    RecurringExpenseStore.instance.ensureLoaded();
    _selectionAnim = AnimationController(
      vsync: this,
      duration: AppMotion.medium,
      reverseDuration: AppMotion.fast,
    );
    _selectionReveal = CurvedAnimation(
      parent: _selectionAnim,
      curve: AppMotion.standard,
      reverseCurve: AppMotion.standard,
    );
    _selectionAnim.addStatusListener(_onSelectionStatus);
  }

  @override
  void dispose() {
    _selectionAnim.removeStatusListener(_onSelectionStatus);
    _selectionReveal.dispose();
    _selectionAnim.dispose();
    super.dispose();
  }

  /// Leaves selection mode once the exit animation has fully run.
  void _onSelectionStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !_selecting) return;
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  /// Starts selection mode, optionally with [selected] already chosen.
  void _enterSelection({Set<String> selected = const <String>{}}) {
    setState(() {
      _selecting = true;
      _selected
        ..clear()
        ..addAll(selected);
    });
    _selectionAnim.forward();
  }

  /// Animates out of selection mode; the status listener then clears it.
  void _exitSelection() {
    if (_selectionAnim.status == AnimationStatus.reverse ||
        _selectionAnim.status == AnimationStatus.dismissed) {
      return;
    }
    _selectionAnim.reverse();
  }

  /// Toggles one transaction in the selection.
  void _toggleExpense(String id) {
    setState(() {
      if (!_selected.add(id)) {
        _selected.remove(id);
      }
    });
  }

  /// Selects a whole day, or clears it when every row is already selected.
  void _toggleDay(List<WaffrTransaction> expenses) {
    final ids = expenses.map((item) => item.id);
    final allSelected = ids.every(_selected.contains);
    setState(() {
      if (allSelected) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
    });
  }

  /// Selects every transaction, or clears them all when all are selected.
  void _toggleAll(List<WaffrTransaction> expenses) {
    final ids = expenses.map((item) => item.id).toSet();
    final allSelected = ids.isNotEmpty && ids.every(_selected.contains);
    setState(() {
      if (allSelected) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
    });
  }

  /// Lets the user pick a date range and selects every transaction inside it.
  Future<void> _pickRange(List<WaffrTransaction> expenses) async {
    if (expenses.isEmpty) return;
    var oldest = expenses.first.dateTime.toLocal();
    for (final expense in expenses) {
      final local = expense.dateTime.toLocal();
      if (local.isBefore(oldest)) oldest = local;
    }
    final now = DateTime.now();
    final firstDate = DateTime(oldest.year, oldest.month, oldest.day);
    final lastDate = DateTime(now.year, now.month, now.day);
    final range = await showWaffrDateRangePicker(
      context: context,
      title: 'نطاق التاريخ',
      firstDate: firstDate,
      lastDate: lastDate.isBefore(firstDate) ? firstDate : lastDate,
    );
    if (!mounted || range == null) return;
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    final matched = <String>{
      for (final expense in expenses)
        if (_dayOf(expense.dateTime).isBefore(start) == false &&
            _dayOf(expense.dateTime).isAfter(end) == false)
          expense.id,
    };
    setState(() {
      _selecting = true;
      _selected
        ..clear()
        ..addAll(matched);
    });
  }

  /// Asks for a format, then shares the selected expenses as PDF or text.
  Future<void> _confirmShare(List<WaffrTransaction> expenses) async {
    final chosen = expenses
        .where((item) => _selected.contains(item.id))
        .toList();
    if (chosen.isEmpty || _sharing) return;
    final format = await showAppDialog<_ExpenseShareFormat>(
      context: context,
      builder: (context) => const _ShareFormatDialog(),
    );
    if (format == null || !mounted) return;
    setState(() => _sharing = true);
    try {
      if (format == _ExpenseShareFormat.pdf) {
        await shareExpenseHistoryPdf(chosen);
      } else {
        await shareExpenseHistoryText(chosen);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'تعذّر مشاركة السجل.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final isIncome = widget.isIncome;
    final title = isIncome ? 'سجل الدخل' : 'سجل المصروفات';
    final summaryLabel = isIncome ? 'كل الدخل' : 'كل المصروفات';
    final emptyMessage = isIncome
        ? 'لا يوجد دخل مسجّل بعد'
        : 'لا يوجد مصروف مسجّل بعد';
    final summaryIcon = isIncome
        ? Icons.payments_outlined
        : Icons.receipt_long_outlined;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: WaffrBackHeader(title: title),
      // Share button (expenses only): enters selection, then shares it.
      floatingActionButton: isIncome
          ? null
          : AnimatedBuilder(
              animation: _listenables,
              builder: (context, _) {
                final liveIds = _store.expenses.map((item) => item.id).toSet();
                final selectedCount = _selected.where(liveIds.contains).length;
                final canShare = _selecting && selectedCount > 0 && !_sharing;
                return FloatingActionButton(
                  onPressed: _selecting
                      ? (canShare ? () => _confirmShare(_store.expenses) : null)
                      : () => _enterSelection(),
                  backgroundColor: canShare || !_selecting
                      ? colors.accent
                      : colors.accent.withValues(alpha: 0.35),
                  foregroundColor: colors.onAccent,
                  elevation: canShare || !_selecting ? 4 : 0,
                  child: const Icon(Icons.share_rounded),
                );
              },
            ),
      body: AnimatedBuilder(
        animation: _listenables,
        builder: (context, _) {
          final items = isIncome ? _store.incomes : _store.expenses;
          final groups = _groupExpensesByDay(items);
          final liveIds = items.map((item) => item.id).toSet();
          final selectedCount = _selected.where(liveIds.contains).length;
          final allSelected =
              items.isNotEmpty &&
              items.every((item) => _selected.contains(item.id));
          return Column(
            children: [
              // Selection bar slides in above the list while selecting.
              if (!isIncome)
                ClipRect(
                  child: SizeTransition(
                    sizeFactor: _selectionReveal,
                    alignment: Alignment.topCenter,
                    child: FadeTransition(
                      opacity: _selectionReveal,
                      child: _SelectionBar(
                        count: selectedCount,
                        allSelected: allSelected,
                        onClose: _exitSelection,
                        onToggleAll: () => _toggleAll(items),
                        onPickRange: () => _pickRange(items),
                      ),
                    ),
                  ),
                ),
              // Ledger total card.
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: GlassContainer(
                  colorType: GlassColorType.surface,
                  borderRadius: 24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summaryLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontFamilyFallback: const ['Tajawal'],
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                            Text(
                              '${formatMoney(_sumExpenses(items))} '
                              '$currencyLabel',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontFamilyFallback: const ['Tajawal'],
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(summaryIcon, color: colors.accent),
                    ],
                  ),
                ),
              ),
              // Day groups, or the empty state.
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: _EmptyState(
                          icon: summaryIcon,
                          message: emptyMessage,
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          18,
                          0,
                          18,
                          isIncome ? 28 : 96,
                        ),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final row = AnimatedBuilder(
                            animation: _selectionReveal,
                            builder: (context, _) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _HistoryDayGroup(
                                  date: group.date,
                                  expenses: group.expenses,
                                  isIncome: isIncome,
                                  selecting:
                                      !isIncome && _selectionReveal.value > 0,
                                  reveal: _selectionReveal.value,
                                  selectedIds: _selected,
                                  onToggleDay: () => _toggleDay(group.expenses),
                                  onLongPressDay: () {
                                    if (_selecting) {
                                      _toggleDay(group.expenses);
                                    } else {
                                      _enterSelection(
                                        selected: group.expenses
                                            .map((item) => item.id)
                                            .toSet(),
                                      );
                                    }
                                  },
                                  onToggleExpense: _toggleExpense,
                                  onLongPressExpense: (expense) {
                                    if (_selecting) {
                                      _toggleExpense(expense.id);
                                    } else {
                                      _enterSelection(selected: {expense.id});
                                    }
                                  },
                                ),
                              );
                            },
                          );
                          // Only the first screenful animates in.
                          return index < 6
                              ? Reveal(
                                  index: index,
                                  play: _playEntrance,
                                  child: row,
                                )
                              : row;
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Local calendar day of [value].
DateTime _dayOf(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Transactions that share the same calendar day for the history list.
class _ExpenseDayGroup {
  final DateTime date;
  final List<WaffrTransaction> expenses;

  const _ExpenseDayGroup(this.date, this.expenses);
}

/// Confirms, deletes the expense, refunds balance, and undoes linked
/// shopping purchases.
Future<void> _undoExpense(
  BuildContext context,
  WaffrTransaction expense,
) async {
  final confirmed = await showAppConfirmDialog(
    context,
    title: 'التراجع عن المصروف',
    message:
        'سيُحذف هذا المصروف من السجل ويُعاد ${formatMoney(expense.amount)} ${currencyLabelFor(expense.currencyCode)} إلى رصيدك.',
    confirmLabel: 'تراجع',
    kind: AppFeedbackKind.warning,
  );

  if (confirmed != true || !context.mounted) return;

  final undone = await TransactionStore.instance.undoExpense(expense.id);
  if (!context.mounted) return;

  if (!undone) {
    showAppSnackBar(context, 'تعذّر التراجع عن هذا المصروف.');
    return;
  }

  await ShoppingListStore.instance.revertPurchaseForExpense(expense.id);
  if (!context.mounted) return;
  showAppSnackBar(context, 'تم التراجع عن المصروف', success: true);
}

/// Confirms, deletes the income entry, and subtracts it from the running
/// balance.
Future<void> _undoIncome(BuildContext context, WaffrTransaction income) async {
  final confirmed = await showAppConfirmDialog(
    context,
    title: 'التراجع عن الدخل',
    message:
        'سيُحذف هذا الدخل من السجل ويُخصم ${formatMoney(income.amount)} ${currencyLabelFor(income.currencyCode)} من رصيدك.',
    confirmLabel: 'تراجع',
    kind: AppFeedbackKind.warning,
  );

  if (confirmed != true || !context.mounted) return;

  final undone = await TransactionStore.instance.undoIncome(income.id);
  if (!context.mounted) return;

  if (!undone) {
    showAppSnackBar(context, 'تعذّر التراجع عن هذا الدخل.');
    return;
  }

  showAppSnackBar(context, 'تم التراجع عن الدخل', success: true);
}

/// [expenses] grouped by local day, newest day first.
List<_ExpenseDayGroup> _groupExpensesByDay(List<WaffrTransaction> expenses) {
  final grouped = <DateTime, List<WaffrTransaction>>{};
  for (final expense in expenses) {
    final local = expense.dateTime.toLocal();
    final date = DateTime(local.year, local.month, local.day);
    grouped.putIfAbsent(date, () => []).add(expense);
  }
  return grouped.entries
      .map((entry) => _ExpenseDayGroup(entry.key, entry.value))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

/// Day header label: today, yesterday, or day and month (plus year when not
/// the current one).
String _historyDateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final difference = calendarDaysBetween(date, today);
  if (difference == 0) return 'اليوم';
  if (difference == 1) return 'أمس';
  if (date.year == today.year) {
    return '${date.day} ${CalendarPeriod.monthName(date.month)}';
  }
  return '${date.day} ${CalendarPeriod.monthName(date.month)} ${date.year}';
}
