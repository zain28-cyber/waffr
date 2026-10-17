// Shopping list: the preview card on the savings screen, the full list sheet
// (add, rename, delete, clear), and the purchase sheet that records an item
// as an expense through ShoppingListStore.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/containers/app_empty_state.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/theme/app_color.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/screens/offline/home/sheets/add_expense_sheet.dart';
import 'package:waffr/widgets/button/glass_button.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/widgets/dialogs/edit_delete_menu.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Opens the full shopping list sheet.
Future<void> showShoppingListSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => const _ShoppingListSheet(),
  );
}

/// Compact teaser on the savings screen; opens the full shopping list sheet.
class ShoppingListPreviewCard extends StatefulWidget {
  /// Creates a [ShoppingListPreviewCard].
  const ShoppingListPreviewCard({super.key});

  @override
  State<ShoppingListPreviewCard> createState() =>
      _ShoppingListPreviewCardState();
}

/// State of [ShoppingListPreviewCard].
class _ShoppingListPreviewCardState extends State<ShoppingListPreviewCard> {
  final ShoppingListStore _store = ShoppingListStore.instance;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        // Show up to three items, then a "+N more" line.
        final colors = _ShoppingColors.of(context);
        final preview = _store.items.take(3).toList(growable: false);

        return GlassButton(
          onTap: () => showShoppingListSheet(context),
          colorType: GlassColorType.surface,
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: icon, title and item count, chevron.
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 21,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'قائمة المشتريات',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontFamilyFallback: ['Tajawal'],
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          preview.isEmpty
                              ? 'أضف ما تحتاج إلى شرائه'
                              : itemsCountLabel(_store.items.length),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontFamilyFallback: ['Tajawal'],
                            fontSize: 11.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded, color: colors.textSecondary),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final item in preview)
                  _PreviewItem(item: item, colors: colors),
                if (_store.items.length > preview.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${itemsCountLabel(_store.items.length - preview.length, other: true)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: ['Tajawal'],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// One preview line under the shopping list teaser, struck through once
/// purchased.
class _PreviewItem extends StatelessWidget {
  final ShoppingItem item;
  final _ShoppingColors colors;

  const _PreviewItem({required this.item, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            item.isPurchased
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 17,
            color: item.isPurchased
                ? colors.accent
                : colors.textSecondary.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
                fontSize: 12.5,
                color: item.isPurchased
                    ? colors.textSecondary
                    : colors.textPrimary,
                decoration: item.isPurchased
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full list: add items, mark purchases, edit / delete, or clear everything.
class _ShoppingListSheet extends StatefulWidget {
  const _ShoppingListSheet();

  @override
  State<_ShoppingListSheet> createState() => _ShoppingListSheetState();
}

/// State of [_ShoppingListSheet]. Owns the new-item text controller.
class _ShoppingListSheetState extends State<_ShoppingListSheet> {
  final ShoppingListStore _store = ShoppingListStore.instance;
  final TextEditingController _itemController = TextEditingController();

  /// True while a new item is being stored; disables the field and button.
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  /// Adds the typed item and clears the field.
  Future<void> _addItem() async {
    final name = _itemController.text.trim();
    if (name.isEmpty || _adding) return;

    setState(() => _adding = true);
    await _store.addItem(name);

    if (!mounted) return;
    _itemController.clear();
    setState(() => _adding = false);
  }

  /// Confirms then wipes all shopping items (recorded expenses stay).
  Future<void> _clearList() async {
    if (_store.items.isEmpty) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'إفراغ قائمة المشتريات',
      message: 'ستُحذف كل العناصر من القائمة. المصروفات المسجّلة لن تتأثر.',
      confirmLabel: 'إفراغ',
      destructive: true,
    );

    if (confirmed != true || !mounted) return;
    await _store.clearAll();
    if (!mounted) return;
    showAppSnackBar(context, 'تم إفراغ قائمة المشتريات', success: true);
  }

  /// Opens the purchase sheet for an unpurchased item.
  Future<void> _purchase(ShoppingItem item) async {
    if (item.isPurchased) return;
    await showPurchaseShoppingItemSheet(context, item);
  }

  /// Same edit / delete menu as the expense categories, anchored at
  /// [anchorContext].
  Future<void> _showItemActions(
    BuildContext anchorContext,
    ShoppingItem item,
  ) async {
    final action = await showEditDeleteMenu(
      context,
      anchorContext: anchorContext,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case EditDeleteAction.edit:
        await _renameItem(item);
      case EditDeleteAction.delete:
        await _removeItem(item);
    }
  }

  /// Asks for a new name and stores it.
  Future<void> _renameItem(ShoppingItem item) async {
    final name = await showAppDialog<String>(
      context: context,
      builder: (_) => _RenameShoppingItemDialog(initialName: item.name),
    );
    if (name == null || !mounted) return;
    await _store.renameItem(item.id, name);
  }

  /// Confirms, then removes the item from the list.
  Future<void> _removeItem(ShoppingItem item) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'حذف «${item.name}»',
      message: item.isPurchased
          ? 'سيُحذف العنصر من القائمة. المصروف المسجّل لشرائه لن يتأثر.'
          : 'سيُحذف العنصر من قائمة المشتريات.',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _store.removeItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ShoppingColors.of(context);

    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        return GlassSheetBody(
          children: [
            const GlassSheetHeader(
              title: 'قائمة المشتريات',
              subtitle: 'احتفظ باحتياجاتك وسجّل المشتريات كمصروفات.',
            ),
            const SizedBox(height: 18),
            // Add row: name field and add button (spinner while saving).
            Row(
              children: [
                Expanded(
                  child: SheetTextField(
                    controller: _itemController,
                    hint: 'اسم العنصر',
                    enabled: !_adding,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: _itemController.text.trim().isEmpty
                      ? colors.textSecondary.withValues(alpha: 0.3)
                      : colors.accent,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: _itemController.text.trim().isEmpty || _adding
                        ? null
                        : _addItem,
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: _adding
                          ? Padding(
                              padding: const EdgeInsets.all(17),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onAccentOf(context),
                              ),
                            )
                          : Icon(
                              Icons.add_rounded,
                              color: AppColors.onAccentOf(context),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Empty state, or a clear button over the item tiles.
            if (_store.items.isEmpty)
              const AppEmptyState(
                icon: Icons.shopping_basket_outlined,
                title: 'قائمة المشتريات فارغة',
                message: 'اكتب اسم ما تحتاج إليه ثم اضغط +.',
              )
            else ...[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: _clearList,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  label: Text(
                    'إفراغ القائمة',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: ['Tajawal'],
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              for (final item in _store.items) ...[
                _ShoppingItemTile(
                  key: ValueKey(item.id),
                  item: item,
                  colors: colors,
                  onTap: () => _purchase(item),
                  onActions: (anchor) => _showItemActions(anchor, item),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// Checkbox row; tap opens the purchase sheet when not yet bought. The dots
/// button (or a long press) opens edit / delete.
class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final _ShoppingColors colors;
  final VoidCallback onTap;
  final ValueChanged<BuildContext> onActions;

  const _ShoppingItemTile({
    super.key,
    required this.item,
    required this.colors,
    required this.onTap,
    required this.onActions,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: sheetFieldColor(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: item.isPurchased ? null : onTap,
        onLongPress: () => onActions(context),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 4, 9),
          child: Row(
            children: [
              Checkbox(
                value: item.isPurchased,
                onChanged: item.isPurchased ? null : (_) => onTap(),
                activeColor: colors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: item.isPurchased
                        ? colors.textSecondary
                        : colors.textPrimary,
                    decoration: item.isPurchased
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.isPurchased ? 'تم الشراء' : 'تسجيل الشراء',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: 10.5,
                  color: item.isPurchased
                      ? colors.textSecondary
                      : colors.accent,
                ),
              ),
              Builder(
                builder: (anchorContext) => IconButton(
                  tooltip: 'تعديل أو حذف',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  onPressed: () => onActions(anchorContext),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 19,
                    color: colors.textSecondary,
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

/// Dialog with a name field for renaming one shopping item; pops the trimmed
/// name, or null on cancel.
class _RenameShoppingItemDialog extends StatefulWidget {
  final String initialName;

  const _RenameShoppingItemDialog({required this.initialName});

  @override
  State<_RenameShoppingItemDialog> createState() =>
      _RenameShoppingItemDialogState();
}

/// State of [_RenameShoppingItemDialog]. Owns the name controller.
class _RenameShoppingItemDialogState extends State<_RenameShoppingItemDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => _controller.text.trim().isNotEmpty;

  /// Pops the dialog with the trimmed name.
  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(
      title: 'تعديل العنصر',
      kind: AppFeedbackKind.info,
      actions: [
        AppDialogAction(
          label: 'إلغاء',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          label: 'حفظ',
          primary: true,
          enabled: _canSave,
          onPressed: _save,
        ),
      ],
      child: SheetTextField(
        controller: _controller,
        hint: 'اسم العنصر',
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}

/// Records an expense for a shopping item and marks it purchased.
Future<void> showPurchaseShoppingItemSheet(
  BuildContext context,
  ShoppingItem item,
) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => _PurchaseShoppingItemSheet(item: item),
  );
}

/// Amount + category form that posts an expense and marks the item bought.
class _PurchaseShoppingItemSheet extends StatefulWidget {
  final ShoppingItem item;

  const _PurchaseShoppingItemSheet({required this.item});

  @override
  State<_PurchaseShoppingItemSheet> createState() =>
      _PurchaseShoppingItemSheetState();
}

/// State of [_PurchaseShoppingItemSheet]. Owns the price controller and
/// the chosen category and currency.
class _PurchaseShoppingItemSheetState
    extends State<_PurchaseShoppingItemSheet> {
  final TextEditingController _amountController = TextEditingController();

  String _category = CategoryStore.instance.defaultLabel;

  /// True while the expense is being saved.
  bool _saving = false;
  late String _currencyCode;

  double get _amount => parseAmount(_amountController.text);

  /// Whether the price is more than the balance in the chosen currency.
  bool get _exceedsBalance =>
      _amount > TransactionStore.instance.balanceFor(_currencyCode);

  bool get _isValid => _amount > 0 && _amount <= 999999999 && !_exceedsBalance;

  @override
  void initState() {
    super.initState();
    _currencyCode = CurrencyStore.instance.activeCode;
    TransactionStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Posts the expense via ShoppingListStore and closes on success; otherwise
  /// explains why it failed (insufficient balance or a generic error).
  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);

    try {
      final saved = await ShoppingListStore.instance.completePurchase(
        itemId: widget.item.id,
        amount: _amount,
        category: _category,
        currencyCode: _currencyCode,
      );

      if (!mounted) return;

      if (saved) {
        AppHaptics.success();
        Navigator.of(context).maybePop();
        return;
      }
    } catch (_) {
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (_amount > TransactionStore.instance.balanceFor(_currencyCode)) {
      showInsufficientBalanceMessage(context);
      return;
    }

    showAppSnackBar(context, 'تعذّر حفظ المصروف. حاول مرة أخرى.');
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheetBody(
      children: [
        GlassSheetHeader(
          title: 'إضافة مصروف',
          subtitle: widget.item.name,
          onNext: _isValid && !_saving ? _save : null,
        ),
        const SizedBox(height: 18),
        SheetAmountField(
          label: 'السعر',
          controller: _amountController,
          helper: _exceedsBalance
              ? 'أكبر من الرصيد المتاح ${formatMoney(TransactionStore.instance.balanceFor(_currencyCode))} ${currencyLabelFor(_currencyCode)}'
              : null,
          currencyCode: _currencyCode,
          onCurrencyChanged: (code) => setState(() => _currencyCode = code),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        const SheetFieldLabel(text: 'التصنيف'),
        ExpenseCategoryGrid(
          selected: _category,
          onSelected: (value) => setState(() => _category = value),
        ),
        const SizedBox(height: 22),
        SheetSaveButton(
          label: 'حفظ المصروف',
          enabled: _isValid && !_saving,
          onTap: _save,
        ),
      ],
    );
  }
}

/// Local light/dark colors for shopping UI.
class _ShoppingColors {
  final Color accent;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const _ShoppingColors({
    required this.accent,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  /// Reads the colors from the current [AppPalette].
  factory _ShoppingColors.of(BuildContext context) {
    final palette = AppPalette.of(context);

    return _ShoppingColors(
      accent: palette.accent,
      surface: palette.surface,
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
    );
  }
}

/// Arabic count phrase for [count] shopping items with the right plural
/// form, e.g.
/// "عنصر واحد محفوظ", "عنصران محفوظان", "3 عناصر محفوظة", "11 عنصراً محفوظاً".
/// With [other], returns the "N other items" form used for the preview's
/// overflow line.
String itemsCountLabel(int count, {bool other = false}) {
  if (count == 1) return other ? 'عنصر آخر' : 'عنصر واحد محفوظ';
  if (count == 2) return other ? 'عنصران آخران' : 'عنصران محفوظان';
  if (count <= 10) return other ? '$count عناصر أخرى' : '$count عناصر محفوظة';
  return other ? '$count عنصراً آخر' : '$count عنصراً محفوظاً';
}
