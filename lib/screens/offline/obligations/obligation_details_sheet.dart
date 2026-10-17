// Obligation details sheet (part of obligations_sheet.dart): one recurring
// expense with its amount, deduct mode, pause and delete actions.

part of 'obligations_sheet.dart';

/// Details and controls for one obligation, looked up live by [id] so the
/// sheet follows store changes (and handles the obligation being removed).
class _ObligationDetailsSheet extends StatefulWidget {
  // Id of the recurring expense in [RecurringExpenseStore].
  final String id;

  const _ObligationDetailsSheet({required this.id});

  @override
  State<_ObligationDetailsSheet> createState() =>
      _ObligationDetailsSheetState();
}

/// State of [_ObligationDetailsSheet]. Rebuilds from [RecurringExpenseStore].
class _ObligationDetailsSheetState extends State<_ObligationDetailsSheet> {
  final RecurringExpenseStore _store = RecurringExpenseStore.instance;

  // Status chip labels.
  static const String _activeLabel = 'مفعّل';
  static const String _stoppedLabel = 'متوقف';

  /// Opens the amount dialog and saves the new amount and currency.
  Future<void> _editAmount(RecurringExpense item) async {
    final colors = _ObligationColors.of(context);
    final result = await showAppDialog<Object>(
      context: context,
      builder: (context) => EditAmountDialog(
        title: obligationTitle(item),
        initialAmount: item.amount,
        accent: colors.accent,
        currencyCode: item.currencyCode,
      ),
    );

    if (!mounted || result is! EditAmountResult) return;

    final saved = await _store.updateAmount(
      item.id,
      result.amount,
      currencyCode: result.currencyCode,
    );
    if (!mounted) return;

    if (!saved) {
      showAppSnackBar(context, 'تعذّر حفظ المبلغ. حاول مرة أخرى.');
      return;
    }
    showAppSnackBar(context, 'تم حفظ المبلغ الجديد', success: true);
  }

  /// Confirms, deletes the obligation, and closes the sheet.
  Future<void> _delete(RecurringExpense item) async {
    final confirm = await showAppConfirmDialog(
      context,
      title: 'حذف الالتزام',
      message:
          'سيُحذف «${obligationTitle(item)}» ولن يُخصم مرة أخرى. المصروفات التي خُصمت سابقاً تبقى في السجل.',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (confirm != true) return;

    await _store.deleteExpense(item.id);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ObligationColors.of(context);

    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final item = _store.byId(widget.id);
        // The obligation was deleted elsewhere.
        if (item == null) {
          return const GlassSheetBody(
            children: [
              GlassSheetHeader(
                title: 'الالتزام',
                subtitle: 'لم يعد هذا الالتزام موجوداً.',
              ),
              SizedBox(height: 12),
            ],
          );
        }

        final now = deviceNow();
        final attention = obligationNeedsAttention(item, now: now);
        final awaiting = attention && item.requiresConfirmation;

        return GlassSheetBody(
          children: [
            // Header, then the tappable amount field.
            GlassSheetHeader(
              title: obligationTitle(item),
              subtitle:
                  '${categoryFor(item.category).label} · ${item.intervalDescription}',
            ),
            const SizedBox(height: 18),
            const SheetFieldLabel(text: 'المبلغ'),
            Material(
              color: sheetFieldColor(context),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _editAmount(item),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${formatMoney(item.amount)} ${currencyLabelFor(item.currencyCode)}',
                          style: _text(
                            colors.textPrimary,
                            size: 17,
                            weight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(Icons.edit_rounded, size: 19, color: colors.accent),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Deduct mode chips.
            const SheetFieldLabel(
              text: 'طريقة الخصم',
              action: SheetInfoButton(
                title: kDeductModeInfoTitle,
                message: kDeductModeInfoMessage,
              ),
            ),
            SheetChoiceChips(
              options: const [kDeductAutomaticLabel, kDeductConfirmLabel],
              selected: item.requiresConfirmation
                  ? kDeductConfirmLabel
                  : kDeductAutomaticLabel,
              onSelected: (value) => _store.setRequiresConfirmation(
                item.id,
                value == kDeductConfirmLabel,
              ),
            ),
            const SizedBox(height: 16),
            // Active / paused chips and the current status line.
            const SheetFieldLabel(text: 'الحالة'),
            SheetChoiceChips(
              options: const [_activeLabel, _stoppedLabel],
              selected: item.enabled ? _activeLabel : _stoppedLabel,
              onSelected: (value) =>
                  _store.setEnabled(item.id, value == _activeLabel),
            ),
            const SizedBox(height: 10),
            Text(
              obligationStatus(item, now: now),
              textAlign: TextAlign.center,
              style: _text(
                attention ? colors.warning : colors.textSecondary,
                size: 12.5,
                weight: attention ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            // Review button when charges wait for confirmation, then delete.
            if (awaiting) ...[
              SheetSaveButton(
                label: 'مراجعة وتأكيد',
                onTap: () {
                  Navigator.of(context).maybePop();
                  showDueObligationsSheet(context);
                },
              ),
              const SizedBox(height: 8),
            ],
            SheetDestructiveButton(
              label: 'حذف الالتزام',
              onTap: () => _delete(item),
            ),
          ],
        );
      },
    );
  }
}
