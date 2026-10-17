// Transaction history rows (part of reportscreen.dart): day groups,
// expense / income rows and the recurring badge.

part of 'reportscreen.dart';

/// Date header plus a glass card listing that day's transactions.
class _HistoryDayGroup extends StatelessWidget {
  final DateTime date;
  final List<WaffrTransaction> expenses;
  // Income history: income titles and undo-income instead of undo-expense.
  final bool isIncome;
  // Multi-select mode; shows the select marks.
  final bool selecting;
  // 0-1 progress of the select marks fading in; taps wait until it is done.
  final double reveal;
  final Set<String> selectedIds;
  // Selection callbacks for the day header and for single rows.
  final VoidCallback? onToggleDay;
  final VoidCallback? onLongPressDay;
  final ValueChanged<String>? onToggleExpense;
  final ValueChanged<WaffrTransaction>? onLongPressExpense;

  const _HistoryDayGroup({
    required this.date,
    required this.expenses,
    this.isIncome = false,
    this.selecting = false,
    this.reveal = 1,
    this.selectedIds = const <String>{},
    this.onToggleDay,
    this.onLongPressDay,
    this.onToggleExpense,
    this.onLongPressExpense,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    // Day mark: empty, partial or checked from the selected rows.
    final selectedCount = expenses
        .where((item) => selectedIds.contains(item.id))
        .length;
    final dayState = selectedCount == 0
        ? _SelectState.empty
        : selectedCount == expenses.length
        ? _SelectState.checked
        : _SelectState.partial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Day header (long-press starts selecting the whole day).
        GestureDetector(
          onLongPress: onLongPressDay,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 7, bottom: 7),
            child: Row(
              children: [
                if (selecting) ...[
                  Opacity(
                    opacity: reveal,
                    child: _SelectMark(
                      state: dayState,
                      onTap: reveal > 0.99 ? (onToggleDay ?? () {}) : () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _historyDateLabel(date),
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Card with one row per transaction; undo is hidden while selecting.
        GlassContainer(
          colorType: GlassColorType.surface,
          borderRadius: 25,
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          child: Column(
            children: [
              for (var index = 0; index < expenses.length; index++) ...[
                if (index > 0)
                  Divider(
                    height: 22,
                    color: colors.textPrimary.withValues(alpha: 0.08),
                  ),
                _HistoryExpenseRow(
                  expense: expenses[index],
                  isIncome: isIncome,
                  selecting: selecting,
                  reveal: reveal,
                  selected: selectedIds.contains(expenses[index].id),
                  onToggle: () => onToggleExpense?.call(expenses[index].id),
                  onLongPress: () => onLongPressExpense?.call(expenses[index]),
                  onUndo: selecting
                      ? null
                      : () => isIncome
                            ? _undoIncome(context, expenses[index])
                            : _undoExpense(context, expenses[index]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Single history row: category/note, timestamp, amount, optional undo.
class _HistoryExpenseRow extends StatelessWidget {
  final WaffrTransaction expense;
  final bool isIncome;
  final bool selecting;
  final double reveal;
  final bool selected;
  // Undo for this transaction; null hides the button.
  final VoidCallback? onUndo;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;

  const _HistoryExpenseRow({
    required this.expense,
    this.isIncome = false,
    this.selecting = false,
    this.reveal = 1,
    this.selected = false,
    this.onUndo,
    this.onToggle,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final category = categoryFor(expense.category);
    final note = expense.note?.trim();
    // Title / subtitle rules differ for income and for recurring expenses.
    final recurring =
        !isIncome && RecurringExpense.isRecurringSource(expense.sourceId);
    final schedule = recurring ? _recurringSchedule(expense) : null;
    final title = isIncome
        ? (note != null && note.isNotEmpty
              ? note
              : _incomeFrequencyLabel(expense.frequency))
        : category.label;
    // A schedule without a note stored its "every N" text as the note; the
    // recurring badge already shows it.
    final noteIsSchedule =
        recurring &&
        note != null &&
        (note == schedule || _looksLikeSchedule(note));
    final subtitle = isIncome && note != null && note.isNotEmpty
        ? _incomeFrequencyLabel(expense.frequency)
        : (!isIncome && !noteIsSchedule ? note : null);
    final icon = isIncome ? Icons.payments_outlined : category.icon;
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: selecting ? onToggle : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Select mark, category icon, text column, then amount and undo.
          if (selecting) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Opacity(
                opacity: reveal,
                child: _SelectMark(
                  state: selected ? _SelectState.checked : _SelectState.empty,
                  onTap: reveal > 0.99 ? (onToggle ?? () {}) : () {},
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 21, color: colors.accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 12.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                if (recurring) ...[
                  const SizedBox(height: 4),
                  _RecurringBadge(
                    schedule: schedule ?? _scheduleFromNote(note),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${formatDate(expense.dateTime)} • '
                  '${formatTime(expense.dateTime)}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 10.5,
                    color: colors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '${formatMoney(expense.amount)} $currencyLabel',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.accent,
                  ),
                ),
              ),
              if (onUndo != null)
                IconButton(
                  tooltip: 'تراجع',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: onUndo,
                  icon: Icon(
                    Icons.undo_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Recurring" pill on history rows posted by a schedule, with the schedule
/// ("كل شهر") next to it when it is still known.
class _RecurringBadge extends StatelessWidget {
  // Schedule description ("every N units"); null hides it.
  final String? schedule;

  const _RecurringBadge({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = TextStyle(
      fontFamily: 'Outfit',
      fontFamilyFallback: const ['Tajawal'],
      fontSize: 10.5,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: colors.accent,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(7, 3, 8, 3),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.accent.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.autorenew_rounded, size: 12, color: colors.accent),
              const SizedBox(width: 4),
              Text('مصروف متكرر', style: text),
            ],
          ),
        ),
        if (schedule != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              schedule!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "كل شهر" for the schedule that posted [expense], if it still exists.
String? _recurringSchedule(WaffrTransaction expense) {
  final id = RecurringExpense.idFromSource(expense.sourceId);
  if (id == null) return null;
  return RecurringExpenseStore.instance.byId(id)?.intervalDescription;
}

/// Matches the Arabic "every N day/week/month" text a schedule stores as the
/// note.
final RegExp _schedulePattern = RegExp(
  r'^كل (\d+ )?(يوم|أسبوع|شهر|أيام|أسابيع|أشهر)$',
);

/// Whether [text] is a stored schedule description.
bool _looksLikeSchedule(String text) => _schedulePattern.hasMatch(text);

/// Deleted schedules: the note may still hold the "every N" text.
String? _scheduleFromNote(String? note) {
  if (note == null || !_looksLikeSchedule(note)) return null;
  return note;
}

/// Row label for an income's frequency.
String _incomeFrequencyLabel(RecurringFrequency frequency) {
  return switch (frequency) {
    RecurringFrequency.weekly => 'دخل أسبوعي',
    RecurringFrequency.monthly => 'دخل شهري',
    RecurringFrequency.none => 'دخل',
  };
}
