// Obligations (library root): the list of recurring expenses, the details
// of one, and the sheet where charges waiting for approval are deducted or
// postponed. Details, due charges and shared labels are part files.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/containers/app_empty_state.dart';
import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/theme/app_color.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/data/models/calendar_period.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/widgets/dialogs/edit_amount_dialog.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/core/utils/calendar_days.dart';

part 'due_obligations_sheet.dart';
part 'obligation_details_sheet.dart';
part 'obligation_labels.dart';

/// Opens the obligations list for the active currency.
Future<void> showObligationsSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => const ObligationsSheet(),
  );
}

/// Opens the sheet of charges waiting for the user's confirmation.
Future<void> showDueObligationsSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => const DueObligationsSheet(),
  );
}

/// List of the active currency's obligations with a monthly total, the next
/// charge, and a banner for charges awaiting confirmation. Tapping one opens
/// its details sheet.
class ObligationsSheet extends StatefulWidget {
  /// Creates a [ObligationsSheet].
  const ObligationsSheet({super.key});

  @override
  State<ObligationsSheet> createState() => _ObligationsSheetState();
}

/// State of [ObligationsSheet]. Rebuilds from [RecurringExpenseStore] and
/// [CurrencyStore].
class _ObligationsSheetState extends State<ObligationsSheet> {
  final RecurringExpenseStore _store = RecurringExpenseStore.instance;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ObligationColors.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([_store, CurrencyStore.instance]),
      builder: (context, _) {
        final code = CurrencyStore.instance.activeCode;
        final now = deviceNow();
        final items = _sorted(_store.itemsFor(code), now);
        final awaiting = _store.awaitingConfirmation(code, now: now);
        final next = _store.nextUpcoming(code, now: now);
        final symbol = currencyLabelFor(code);

        // Header, then summary, awaiting banner and one tile per obligation.
        return GlassSheetBody(
          children: [
            const GlassSheetHeader(
              title: 'الالتزامات',
              subtitle:
                  'المصروفات التي تتكرر بانتظام، مثل الإيجار والاشتراكات.',
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const _EmptyObligations()
            else ...[
              _SummaryBox(
                colors: colors,
                monthlyTotal:
                    '${formatMoney(_store.monthlyTotal(code))} $symbol',
                nextLine: next == null
                    ? null
                    : '${obligationTitle(next)}، ${obligationDate(next.nextDueAt, now: now)}',
              ),
              if (awaiting.isNotEmpty) ...[
                const SizedBox(height: 10),
                _AwaitingBanner(
                  colors: colors,
                  count: awaiting.length,
                  onTap: () => showDueObligationsSheet(context),
                ),
              ],
              const SizedBox(height: 16),
              const SheetFieldLabel(text: 'كل الالتزامات'),
              for (final item in items) ...[
                _ObligationTile(
                  item: item,
                  colors: colors,
                  now: now,
                  onTap: () => _openDetails(item),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        );
      },
    );
  }

  /// Waiting charges first, then by next charge date; stopped ones last.
  List<RecurringExpense> _sorted(List<RecurringExpense> items, DateTime now) {
    int rank(RecurringExpense item) {
      if (!item.enabled) return 2;
      return obligationNeedsAttention(item, now: now) ? 0 : 1;
    }

    final list = [...items];
    list.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      return a.nextDueAt.compareTo(b.nextDueAt);
    });
    return list;
  }

  /// Opens the details sheet for [item] on top of this one.
  void _openDetails(RecurringExpense item) {
    showGlassSheet<void>(
      context: context,
      builder: (context) => _ObligationDetailsSheet(id: item.id),
    );
  }
}

/// Approximate monthly total and the next upcoming charge.
class _SummaryBox extends StatelessWidget {
  final _ObligationColors colors;
  final String monthlyTotal;
  final String? nextLine;

  const _SummaryBox({
    required this.colors,
    required this.monthlyTotal,
    required this.nextLine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: sheetFieldColor(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المجموع الشهري التقريبي',
            style: _text(
              colors.textSecondary,
              size: 12.5,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            monthlyTotal,
            style: _text(colors.accent, size: 22, weight: FontWeight.bold),
          ),
          if (nextLine != null) ...[
            const SizedBox(height: 6),
            Text(
              'الدفعة القادمة: $nextLine',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _text(colors.textSecondary, size: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Warning-tinted banner that opens the due-obligations sheet.
class _AwaitingBanner extends StatelessWidget {
  final _ObligationColors colors;
  final int count;
  final VoidCallback onTap;

  const _AwaitingBanner({
    required this.colors,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Icon(
                Icons.pending_actions_rounded,
                size: 22,
                color: colors.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  count == 1
                      ? 'لديك التزام بانتظار تأكيدك'
                      : 'لديك ${obligationsCountLabel(count)} بانتظار تأكيدك',
                  style: _text(
                    colors.textPrimary,
                    size: 13.5,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'مراجعة',
                style: _text(colors.warning, size: 13, weight: FontWeight.w700),
              ),
              Icon(Icons.chevron_left_rounded, color: colors.warning),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state explaining how to add an obligation.
class _EmptyObligations extends StatelessWidget {
  const _EmptyObligations();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.event_repeat_outlined,
      title: 'لا توجد التزامات بعد',
      message: 'لإضافة التزام، اختر «إضافة مصروف» ثم «مصروف متكرر».',
    );
  }
}

/// One obligation row: icon, title, amount / interval / deduct mode, and
/// status. Paused obligations are dimmed.
class _ObligationTile extends StatelessWidget {
  final RecurringExpense item;
  final _ObligationColors colors;
  final DateTime now;
  final VoidCallback onTap;

  const _ObligationTile({
    required this.item,
    required this.colors,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final attention = obligationNeedsAttention(item, now: now);
    final category = categoryFor(item.category);
    final statusColor = attention ? colors.warning : colors.textSecondary;

    return Opacity(
      opacity: item.enabled ? 1 : 0.6,
      child: Material(
        color: sheetFieldColor(context),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(category.icon, size: 19, color: colors.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obligationTitle(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(
                          colors.textPrimary,
                          size: 14,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatMoney(item.amount)} ${currencyLabelFor(item.currencyCode)} · ${item.intervalDescription} · '
                        '${item.requiresConfirmation ? kDeductConfirmLabel : kDeductAutomaticLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(colors.textSecondary, size: 11.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        obligationStatus(item, now: now),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(
                          statusColor,
                          size: 11.5,
                          weight: attention ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
