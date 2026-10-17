// Saved-expense box opened from the star on the expense sheet. Same frame as
// the custom-category box: a grid of tiles plus Cancel / Add actions.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/containers/app_empty_state.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/data/models/expense_preset.dart';
import 'package:waffr/data/stores/expense_preset_store.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// What the user chose in the box.
sealed class ExpensePresetChoice {
  /// Base constructor for the choice subclasses.
  const ExpensePresetChoice();
}

/// "إضافة": save the expense being entered as a preset when it is saved.
class ExpensePresetMark extends ExpensePresetChoice {
  /// Creates a [ExpensePresetMark].
  const ExpensePresetMark();
}

/// The star was already filled and the user no longer wants to save it.
class ExpensePresetUnmark extends ExpensePresetChoice {
  /// Creates a [ExpensePresetUnmark].
  const ExpensePresetUnmark();
}

/// Fill the expense form from [preset].
class ExpensePresetSelected extends ExpensePresetChoice {
  /// The saved expense the user tapped.
  final ExpensePreset preset;

  /// Creates a [ExpensePresetSelected].
  const ExpensePresetSelected(this.preset);
}

/// Opens the saved-expenses dialog. [marked] is true when the star is already
/// filled, which turns the primary action into "unmark". Returns null when
/// the dialog is cancelled.
Future<ExpensePresetChoice?> showExpensePresetsDialog(
  BuildContext context, {
  required bool marked,
}) {
  return showAppDialog<ExpensePresetChoice>(
    context: context,
    builder: (_) => _ExpensePresetsDialog(marked: marked),
  );
}

/// Dialog listing saved expense presets as a grid.
class _ExpensePresetsDialog extends StatefulWidget {
  // Whether the current expense is already marked to be saved as a preset.
  final bool marked;

  const _ExpensePresetsDialog({required this.marked});

  @override
  State<_ExpensePresetsDialog> createState() => _ExpensePresetsDialogState();
}

/// State of [_ExpensePresetsDialog]. Listens to [ExpensePresetStore].
class _ExpensePresetsDialogState extends State<_ExpensePresetsDialog> {
  final ExpensePresetStore _store = ExpensePresetStore.instance;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
  }

  /// Confirms, then removes [preset] from the store (long-press on a tile).
  Future<void> _delete(ExpensePreset preset) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'حذف المصروف المحفوظ',
      message:
          'سيُحذف «${_titleOf(preset)}» من المصروفات المحفوظة. '
          'المصروفات المسجّلة لا تتأثر.',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _store.remove(preset.id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = palette.accent;
    final surface = palette.surface;
    final size = MediaQuery.sizeOf(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: size.width > 460 ? 400 : size.width - 40,
        constraints: BoxConstraints(maxHeight: size.height * 0.72),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row with the help button.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'المصروفات المحفوظة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const SheetInfoButton(title: _helpTitle, message: _helpMessage),
              ],
            ),
            const SizedBox(height: 14),
            // Preset grid, or an empty state.
            Flexible(
              child: ListenableBuilder(
                listenable: _store,
                builder: (context, _) {
                  final presets = _store.items;
                  if (presets.isEmpty) {
                    return const _EmptyPresets();
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    itemCount: presets.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 0.92,
                        ),
                    itemBuilder: (context, index) {
                      final preset = presets[index];
                      return _PresetTile(
                        key: ValueKey(preset.id),
                        preset: preset,
                        onTap: () =>
                            Navigator.of(context)
                                .pop(ExpensePresetSelected(preset)),
                        onLongPress: () => _delete(preset),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Cancel, and add / un-add the current expense as a preset.
            Row(
              children: [
                Expanded(
                  child: AppDialogActionButton(
                    action: AppDialogAction(
                      label: 'إلغاء',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppDialogActionButton(
                    action: AppDialogAction(
                      label: widget.marked ? 'إلغاء الإضافة' : 'إضافة',
                      primary: true,
                      onPressed: () => Navigator.of(context).pop(
                        widget.marked
                            ? const ExpensePresetUnmark()
                            : const ExpensePresetMark(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Help dialog title for the saved-expenses box (opened from the (i) button).
const String _helpTitle = 'ما هي المصروفات المحفوظة؟';

/// Help dialog body: what presets are and how to save, use and delete them.
const String _helpMessage =
    'المصروفات المحفوظة توفّر عليك إعادة كتابة المصروفات التي تتكرر '
    'عندك، مثل الخبز أو أجرة المواصلات.\n\n'
    'لحفظ مصروف: أدخل المبلغ والتصنيف والملاحظة كالمعتاد، ثم اضغط النجمة '
    'واختر «إضافة». تصبح النجمة خضراء، وعند الضغط على «حفظ المصروف» يُسجَّل '
    'المصروف وتُحفظ معه نسخة هنا.\n\n'
    'لاستخدام مصروف محفوظ: اضغط النجمة واختر البطاقة المناسبة، فتُملأ '
    'الحقول تلقائياً، ويمكنك تعديلها قبل الحفظ.\n\n'
    'لحذف مصروف محفوظ: اضغط على بطاقته مطولاً. حذفه لا يؤثر على '
    'المصروفات المسجّلة سابقاً.';

/// Display name of a preset: its note, or the category when there is none.
String _titleOf(ExpensePreset preset) {
  final note = preset.note?.trim();
  return note == null || note.isEmpty ? preset.category : note;
}

/// Empty state shown when no presets are saved.
class _EmptyPresets extends StatelessWidget {
  const _EmptyPresets();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.star_border_rounded,
      title: 'لا توجد مصروفات محفوظة بعد',
    );
  }
}

/// Category tile shape from the expense grid, with the item name under it.
/// Shows the total (amount times multiplier) in the preset's currency.
class _PresetTile extends StatelessWidget {
  final ExpensePreset preset;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PresetTile({
    super.key,
    required this.preset,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = palette.accent;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;
    final category = categoryFor(preset.category);
    final note = preset.note?.trim() ?? '';

    return Material(
      color: sheetFieldColor(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: 18, color: accent),
              const SizedBox(height: 4),
              Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: const ['Tajawal'],
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                note.isEmpty ? 'بدون ملاحظة' : note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: const ['Tajawal'],
                  fontSize: 10.5,
                  color: textSecondary.withValues(
                    alpha: note.isEmpty ? 0.6 : 1,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${formatMoney(preset.total)} '
                  '${currencyLabelFor(preset.currencyCode)}',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
