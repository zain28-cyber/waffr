// Due obligations sheet (part of obligations_sheet.dart): deduct or postpone
// each obligation that is waiting for the user's confirmation.

part of 'obligations_sheet.dart';

/// What to do with one waiting obligation: deduct one payment, deduct every
/// missed payment, or postpone.
enum _DueAction { deductOne, deductAll, postpone }

/// How long to postpone a waiting obligation.
enum _PostponeOption { day, threeDays, week, nextIncome }

/// Chip labels for [_PostponeOption].
extension on _PostponeOption {
  /// Chip label in the "remind me after" row.
  String get label => switch (this) {
    _PostponeOption.day => 'يوم',
    _PostponeOption.threeDays => '3 أيام',
    _PostponeOption.week => 'أسبوع',
    _PostponeOption.nextIncome => 'دخل جديد',
  };
}

/// Lists every obligation (all currencies) waiting for confirmation, with a
/// deduct / postpone choice per item, and applies all choices on confirm.
class DueObligationsSheet extends StatefulWidget {
  /// Creates a [DueObligationsSheet].
  const DueObligationsSheet({super.key});

  @override
  State<DueObligationsSheet> createState() => _DueObligationsSheetState();
}

/// State of [DueObligationsSheet].
class _DueObligationsSheetState extends State<DueObligationsSheet> {
  final RecurringExpenseStore _store = RecurringExpenseStore.instance;

  // Chosen action and postpone option per obligation id (defaults apply when
  // missing: deduct one, postpone one day).
  final Map<String, _DueAction> _actions = {};
  final Map<String, _PostponeOption> _postpone = {};
  // True while choices are being applied, to block a second tap.
  bool _saving = false;

  /// Snapshot so items do not vanish while the user is choosing.
  List<RecurringExpense>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Collects waiting obligations across all currencies, soonest first.
  Future<void> _load() async {
    await _store.ensureLoaded();
    if (!mounted) return;
    final now = deviceNow();
    final items = <RecurringExpense>[];
    for (final code in {for (final item in _store.items) item.currencyCode}) {
      items.addAll(_store.awaitingConfirmation(code, now: now));
    }
    items.sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    setState(() => _items = items);
  }

  /// Applies each choice in turn, closes the sheet, and reports the outcome.
  Future<void> _confirm() async {
    final items = _items ?? const [];
    if (_saving || items.isEmpty) return;
    setState(() => _saving = true);

    var deducted = 0;
    var shortOfBalance = false;
    var postponed = 0;

    for (final item in items) {
      final action = _actions[item.id] ?? _DueAction.deductOne;
      switch (action) {
        case _DueAction.deductOne:
        case _DueAction.deductAll:
          final all = action == _DueAction.deductAll;
          final wanted = all ? item.dueDates(deviceNow()).length : 1;
          final posted = await _store.confirmDue(item.id, all: all);
          deducted += posted;
          if (posted < wanted) shortOfBalance = true;
        case _DueAction.postpone:
          final option = _postpone[item.id] ?? _PostponeOption.day;
          await _store.postpone(
            item.id,
            untilIncome: option == _PostponeOption.nextIncome,
            after: switch (option) {
              _PostponeOption.day => const Duration(days: 1),
              _PostponeOption.threeDays => const Duration(days: 3),
              _PostponeOption.week => const Duration(days: 7),
              _PostponeOption.nextIncome => null,
            },
          );
          postponed++;
      }
    }

    if (!mounted) return;
    Navigator.of(context).maybePop();

    // One snack bar summarising the outcome.
    if (shortOfBalance) {
      showAppSnackBar(
        context,
        'رصيدك لا يكفي لخصم بعض الدفعات، فبقيت بانتظار تأكيدك.',
        kind: AppFeedbackKind.warning,
      );
    } else if (deducted > 0 && postponed > 0) {
      showAppSnackBar(context, 'تم الخصم والتأجيل كما اخترت', success: true);
    } else if (deducted > 0) {
      showAppSnackBar(context, 'تم خصم المبلغ من رصيدك', success: true);
    } else {
      showAppSnackBar(
        context,
        'تم التأجيل، وسنذكّرك في الموعد الذي اخترته',
        kind: AppFeedbackKind.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ObligationColors.of(context);
    final items = _items;

    return GlassSheetBody(
      children: [
        const GlassSheetHeader(
          title: 'التزامات بانتظار تأكيدك',
          subtitle: 'اختر لكل التزام: خصم المبلغ الآن أو تأجيله إلى وقت لاحق.',
        ),
        const SizedBox(height: 16),
        // Loading, empty, or one card per waiting obligation plus confirm.
        if (items == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          const AppEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'لا توجد التزامات بانتظار تأكيدك',
          )
        else ...[
          for (final item in items) ...[
            _DueItemCard(
              item: item,
              colors: colors,
              action: _actions[item.id] ?? _DueAction.deductOne,
              postpone: _postpone[item.id] ?? _PostponeOption.day,
              onAction: (value) => setState(() => _actions[item.id] = value),
              onPostpone: (value) => setState(() => _postpone[item.id] = value),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          SheetSaveButton(label: 'تأكيد', enabled: !_saving, onTap: _confirm),
        ],
      ],
    );
  }
}

/// One waiting obligation: title, amount, how much is due, the action
/// chips, and the postpone options when postponing.
class _DueItemCard extends StatelessWidget {
  final RecurringExpense item;
  final _ObligationColors colors;
  final _DueAction action;
  final _PostponeOption postpone;
  final ValueChanged<_DueAction> onAction;
  final ValueChanged<_PostponeOption> onPostpone;

  // Action chip labels; one-payment items get a plain "deduct".
  static const String _deductLabel = 'خصم';
  static const String _deductOneLabel = 'خصم دفعة';
  static const String _deductAllLabel = 'خصم الكل';
  static const String _postponeLabel = 'تأجيل';

  const _DueItemCard({
    required this.item,
    required this.colors,
    required this.action,
    required this.postpone,
    required this.onAction,
    required this.onPostpone,
  });

  @override
  Widget build(BuildContext context) {
    final count = item.dueDates(deviceNow()).length;
    final symbol = currencyLabelFor(item.currencyCode);
    final several = count > 1;

    // Several missed payments offer deduct-one vs deduct-all.
    final options = several
        ? const [_deductOneLabel, _deductAllLabel, _postponeLabel]
        : const [_deductLabel, _postponeLabel];
    final selected = switch (action) {
      _DueAction.postpone => _postponeLabel,
      _DueAction.deductAll => several ? _deductAllLabel : _deductLabel,
      _DueAction.deductOne => several ? _deductOneLabel : _deductLabel,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        border: Border.all(color: colors.textSecondary.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title and amount, then what is due.
          Row(
            children: [
              Expanded(
                child: Text(
                  obligationTitle(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    colors.textPrimary,
                    size: 15,
                    weight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${formatMoney(item.amount)} $symbol',
                style: _text(colors.accent, size: 15, weight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            several
                ? 'مستحق عن ${paymentsLabel(count)}، المجموع ${formatMoney(item.amount * count)} $symbol'
                : 'موعده ${obligationDate(item.nextDueAt)}',
            style: _text(colors.textSecondary, size: 12),
          ),
          const SizedBox(height: 10),
          // Action chips, then the postpone options when postponing.
          SheetChoiceChips(
            options: options,
            selected: selected,
            onSelected: (value) => onAction(switch (value) {
              _postponeLabel => _DueAction.postpone,
              _deductAllLabel => _DueAction.deductAll,
              _ => _DueAction.deductOne,
            }),
          ),
          SheetExpand(
            visible: action == _DueAction.postpone,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                const SheetFieldLabel(text: 'ذكّرني بعد'),
                SheetChoiceChips(
                  options: [
                    for (final option in _PostponeOption.values) option.label,
                  ],
                  selected: postpone.label,
                  onSelected: (value) => onPostpone(
                    _PostponeOption.values.firstWhere(
                      (option) => option.label == value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
