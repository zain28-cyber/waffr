// Lists finished savings goals with their completed amounts and dates.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/containers/app_empty_state.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Opens the sheet listing goals that have already been completed.
Future<void> showCompletedGoalsSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => const _CompletedGoalsSheet(),
  );
}

/// Sheet body listing goals that have already hit their target, or an
/// empty state when there are none.
class _CompletedGoalsSheet extends StatefulWidget {
  const _CompletedGoalsSheet();

  @override
  State<_CompletedGoalsSheet> createState() => _CompletedGoalsSheetState();
}

/// State of [_CompletedGoalsSheet]. Rebuilds once the ledger has loaded.
class _CompletedGoalsSheetState extends State<_CompletedGoalsSheet> {
  final TransactionStore _store = TransactionStore.instance;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;
    final accent = palette.accent;
    final goals = _store.completedGoals;

    return GlassSheetBody(
      children: [
        const GlassSheetHeader(
          title: 'الأهداف المحققة',
          subtitle: 'سجل الأهداف التي اكتملت.',
        ),
        const SizedBox(height: 12),
        if (goals.isEmpty)
          const AppEmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'لا توجد أهداف محققة بعد',
            message: 'عندما تكمل هدفاً يظهر هنا.',
          )
        else
          for (final goal in goals) ...[
            _CompletedGoalCard(
              goal: goal,
              accent: accent,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

/// One finished goal: name, target, amount reached, duration, and
/// completion date.
class _CompletedGoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  const _CompletedGoalCard({
    required this.goal,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final total = goal.completedAmount ?? goal.targetAmount;
    final completed = goal.completedAt;

    return GlassContainer(
      colorType: GlassColorType.surface,
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            goal.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'المستهدف: ${formatMoney(goal.targetAmount)} $currencyLabel',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 13,
              color: textSecondary,
            ),
          ),
          Text(
            'المبلغ المجموع: ${formatMoney(total)} $currencyLabel',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'المدة: ${goal.duration.label}',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 12.5,
              color: textSecondary,
            ),
          ),
          if (completed != null)
            Text(
              'تاريخ الإنجاز: ${formatDate(completed)}',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
                fontSize: 12.5,
                color: textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
