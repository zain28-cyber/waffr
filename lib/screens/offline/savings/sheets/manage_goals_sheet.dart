// Reorder, delete, or add active savings goals.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/motion/motion.dart';
import 'package:waffr/widgets/button/app_primary_button.dart';
import 'package:waffr/widgets/containers/app_empty_state.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/screens/offline/savings/sheets/create_goal_sheet.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Opens the sheet for reordering, deleting and adding active goals.
Future<void> showManageGoalsSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => const _ManageGoalsSheet(),
  );
}

/// Sheet body with reorderable active goals and an add-goal button.
/// Builds its own glass shell instead of using `GlassSheetBody`.
class _ManageGoalsSheet extends StatefulWidget {
  const _ManageGoalsSheet();

  @override
  State<_ManageGoalsSheet> createState() => _ManageGoalsSheetState();
}

/// State of [_ManageGoalsSheet]. Rebuilds from [TransactionStore] changes.
class _ManageGoalsSheetState extends State<_ManageGoalsSheet> {
  final TransactionStore _store = TransactionStore.instance;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
  }

  /// Asks before permanently removing a goal from the store.
  Future<void> _confirmDelete(SavingsGoal goal) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'حذف الهدف',
      message: 'هل أنت متأكد من حذف هذا الهدف؟',
      confirmLabel: 'حذف',
      destructive: true,
    );

    if (confirmed == true) {
      await _store.deleteGoal(goal.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = palette.accent;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;

    // Own sheet chrome: rounded glass top, safe-area padding.
    return GlassContainer(
      colorType: GlassColorType.surface,
      tintOpacity: 1,
      radius: const BorderRadius.vertical(top: Radius.circular(34)),
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: AnimatedBuilder(
            animation: _store,
            builder: (context, _) {
              final goals = _store.activeGoals;
              final maxListHeight = MediaQuery.sizeOf(context).height * 0.48;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header, then the goal list capped at about half the screen height.
                  const GlassSheetHeader(
                    title: 'إدارة الأهداف',
                    subtitle: 'اسحب لتغيير الأولوية، أو أضف هدفاً جديداً.',
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxListHeight),
                    child: goals.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.flag_outlined,
                            title: 'لا توجد أهداف حالياً',
                          )
                        // Drag order is the goal priority; the store persists it.
                        : ReorderableListView.builder(
                            shrinkWrap: true,
                            primary: false,
                            buildDefaultDragHandles: false,
                            padding: EdgeInsets.zero,
                            itemCount: goals.length,
                            // Lift the dragged row with a soft elevation.
                            proxyDecorator: (child, index, animation) {
                              return AnimatedBuilder(
                                animation: animation,
                                builder: (context, _) {
                                  final t = AppMotion.soft.transform(
                                    animation.value,
                                  );
                                  return Material(
                                    color: Colors.transparent,
                                    elevation: 4 * t,
                                    borderRadius: BorderRadius.circular(22),
                                    child: child,
                                  );
                                },
                              );
                            },
                            onReorderItem: _store.reorderActiveGoals,
                            itemBuilder: (context, index) {
                              final goal = goals[index];
                              return Padding(
                                key: ValueKey(goal.id),
                                padding: EdgeInsets.only(
                                  bottom: index == goals.length - 1 ? 0 : 10,
                                ),
                                child: _ManageGoalRow(
                                  index: index,
                                  goal: goal,
                                  saved: _store.currentSaved(goal),
                                  accent: accent,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  onDelete: () => _confirmDelete(goal),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Add a goal on top of this sheet.
                  AppPrimaryButton(
                    label: 'إضافة هدف',
                    icon: Icons.add_rounded,
                    onTap: () => showCreateGoalSheet(context),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Drag handle, progress summary, and delete for one goal in the manage list.
class _ManageGoalRow extends StatelessWidget {
  final int index;
  final SavingsGoal goal;
  final double saved;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onDelete;

  const _ManageGoalRow({
    required this.index,
    required this.goal,
    required this.saved,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = goal.targetAmount <= 0
        ? 0.0
        : (saved / goal.targetAmount).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: sheetFieldColor(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: Icon(
                Icons.drag_handle_rounded,
                color: textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedRatio(
                    value: ratio,
                    builder: (context, shown) => LinearProgressIndicator(
                      value: shown,
                      minHeight: 8,
                      backgroundColor: textPrimary.withValues(alpha: 0.08),
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatMoney(saved)} / ${formatMoney(goal.targetAmount)}'
                  '  ·  ${(ratio * 100).round()}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: textPrimary.withValues(alpha: 0.08),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onDelete,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: textPrimary.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
