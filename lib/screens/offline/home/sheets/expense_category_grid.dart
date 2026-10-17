// Expense category grid (part of add_expense_sheet.dart): the selectable
// category tiles, the smart category hint and the custom category dialog.

part of 'add_expense_sheet.dart';

/// Built-in + custom categories; long-press a tile to remove it (custom tiles
/// can also be edited).
class ExpenseCategoryGrid extends StatefulWidget {
  /// Label of the currently selected category.
  final String selected;

  /// Called with a category label when a tile is tapped, a custom category is
  /// created, or the selected one is renamed or removed.
  final ValueChanged<String> onSelected;

  /// Creates a [ExpenseCategoryGrid].
  const ExpenseCategoryGrid({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<ExpenseCategoryGrid> createState() => _ExpenseCategoryGridState();
}

/// State of [ExpenseCategoryGrid].
class _ExpenseCategoryGridState extends State<ExpenseCategoryGrid> {
  @override
  void initState() {
    super.initState();
    CategoryStore.instance.ensureLoaded();
  }

  /// Opens the dialog and selects the new custom category once it is added.
  Future<void> _createCustom() async {
    final draft = await _openCategoryDialog();
    if (draft == null || !mounted) return;

    final created = await CategoryStore.instance.addCustom(
      draft.label,
      iconIndex: draft.iconIndex,
    );
    if (created == null || !mounted) return;

    widget.onSelected(created);
  }

  /// Name + icon dialog; prefilled when [editing] a custom category.
  Future<_CustomCategoryDraft?> _openCategoryDialog({
    ExpenseCategory? editing,
  }) {
    final store = CategoryStore.instance;
    return showAppDialog<_CustomCategoryDraft>(
      context: context,
      builder: (_) => _CustomCategoryNameDialog(
        title: editing == null ? 'تصنيف مخصص' : 'تعديل التصنيف',
        submitLabel: editing == null ? 'إضافة' : 'حفظ',
        initialLabel: editing?.label,
        initialIconIndex: editing == null
            ? 0
            : store.iconIndexOf(editing.label),
        ignoring: editing?.label,
      ),
    );
  }

  /// Long-press menu: custom categories can be edited or removed; built-in
  /// ones can be removed.
  Future<void> _showActions(
    BuildContext tileContext,
    ExpenseCategory category,
  ) async {
    final store = CategoryStore.instance;
    final custom = store.isCustom(category.label);
    if (!custom && !store.isBuiltIn(category.label)) return;

    final action = await showEditDeleteMenu(
      context,
      anchorContext: tileContext,
      allowEdit: custom,
    );

    if (!mounted || action == null) return;

    switch (action) {
      case EditDeleteAction.edit:
        await _editCustom(category);
      case EditDeleteAction.delete:
        await _deleteCategory(category.label);
    }
  }

  /// Renames a custom category and keeps it selected if it was.
  Future<void> _editCustom(ExpenseCategory category) async {
    final store = CategoryStore.instance;
    final draft = await _openCategoryDialog(editing: category);
    if (draft == null || !mounted) return;

    final renamed = await store.renameCustom(
      category.label,
      draft.label,
      iconIndex: draft.iconIndex,
    );
    if (renamed == null || !mounted) return;

    if (widget.selected == category.label) {
      widget.onSelected(renamed);
    }
  }

  /// Removes a category after confirmation. Old expenses keep the label, icon
  /// and color of a removed category.
  Future<void> _deleteCategory(String label) async {
    final store = CategoryStore.instance;
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'حذف تصنيف «$label»',
      message: store.isBuiltIn(label)
          ? 'لن يظهر في قائمة التصنيفات بعد الآن. المصروفات السابقة تبقى كما هي، '
                'ويمكنك إعادته بإضافة تصنيف مخصص بالاسم نفسه.'
          : 'لن يظهر في قائمة التصنيفات بعد الآن. المصروفات السابقة تبقى كما هي.',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final removed = await store.removeCategory(label);
    if (!removed || !mounted) return;

    if (widget.selected == label) {
      widget.onSelected(store.defaultLabel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.sizeOf(context, AppMotion.medium),
      curve: AppMotion.enter,
      alignment: Alignment.topCenter,
      child: ListenableBuilder(
        listenable: CategoryStore.instance,
        builder: (context, _) {
          final categories = CategoryStore.instance.selectableCategories;
          // Five per row, with the "add custom" tile last.
          return GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1.12,
            children: [
              for (final category in categories)
                // Builder gives each tile its own context to anchor the
                // long-press menu.
                Builder(
                  builder: (tileContext) {
                    return _CategoryTile(
                      key: ValueKey(category.label),
                      category: category,
                      isSelected: category.label == widget.selected,
                      onTap: () => widget.onSelected(category.label),
                      onLongPress: () => _showActions(tileContext, category),
                    );
                  },
                ),
              _CategoryTile(
                key: const ValueKey('__custom_action__'),
                category: customCategoryAction,
                isSelected: false,
                isAction: true,
                onTap: _createCustom,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Name and icon chosen in [_CustomCategoryNameDialog].
class _CustomCategoryDraft {
  final String label;
  final int iconIndex;

  const _CustomCategoryDraft({required this.label, required this.iconIndex});
}

/// Name + icon picker used when creating or renaming a custom category.
class _CustomCategoryNameDialog extends StatefulWidget {
  final String title;
  final String submitLabel;
  final String? initialLabel;
  final int initialIconIndex;
  // Label to skip in the duplicate-name check (the one being renamed).
  final String? ignoring;

  const _CustomCategoryNameDialog({
    this.title = 'تصنيف مخصص',
    this.submitLabel = 'إضافة',
    this.initialLabel,
    this.initialIconIndex = 0,
    this.ignoring,
  });

  @override
  State<_CustomCategoryNameDialog> createState() =>
      _CustomCategoryNameDialogState();
}

/// State of [_CustomCategoryNameDialog]. Owns the name controller and the
/// validation error shown under it.
class _CustomCategoryNameDialogState extends State<_CustomCategoryNameDialog> {
  late final TextEditingController _controller;
  String? _error;
  late int _iconIndex;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLabel ?? '');
    _iconIndex = clampCustomIconIndex(widget.initialIconIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Validates the name with [CategoryStore] and pops the draft when valid.
  void _submit() {
    final error = CategoryStore.instance.validateName(
      _controller.text,
      ignoring: widget.ignoring,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      _CustomCategoryDraft(
        label: _controller.text.trim(),
        iconIndex: _iconIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = palette.accent;
    final textPrimary = palette.textPrimary;
    final surface = palette.surface;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    final width = MediaQuery.sizeOf(context).width;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width > 460 ? 400 : width - 40,
        height: maxHeight,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
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
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Title and name field.
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                textAlign: TextAlign.center,
                maxLength: 16,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'مثال: إيجار، قهوة...',
                  errorText: _error,
                  counterText: '',
                  filled: true,
                  fillColor: sheetFieldColor(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Icon picker grid.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'الأيقونة',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  itemCount: customCategoryIconChoices.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, i) {
                    return _IconChoice(
                      icon: customCategoryIconChoices[i],
                      selected: i == _iconIndex,
                      accent: accent,
                      onTap: () => setState(() => _iconIndex = i),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Cancel / submit buttons.
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
                        label: widget.submitLabel,
                        primary: true,
                        onPressed: _submit,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One round icon option in the custom category icon picker.
class _IconChoice extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          return Center(
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.fast),
              curve: AppMotion.enter,
              width: side,
              height: side,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? accent : sheetFieldColor(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? AppColors.onAccentOf(context) : accent,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One category tile in [ExpenseCategoryGrid]. [isAction] styles the
/// trailing "add custom category" tile.
class _CategoryTile extends StatelessWidget {
  final ExpenseCategory category;
  final bool isSelected;
  final bool isAction;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CategoryTile({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final accent = palette.accent;
    final textPrimary = palette.textPrimary;

    final onAccent = AppColors.onAccentOf(context);
    final foreground = isSelected ? onAccent : textPrimary;
    final iconColor = isSelected ? onAccent : accent;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.medium),
        curve: AppMotion.enter,
        decoration: BoxDecoration(
          color: isSelected
              ? accent
              : isAction
              ? sheetFieldColor(context).withValues(alpha: 0.55)
              : sheetFieldColor(context),
          borderRadius: BorderRadius.circular(14),
          border: isAction
              ? Border.all(color: accent.withValues(alpha: 0.32), width: 1.2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(category.icon, size: 18, color: iconColor),
            const SizedBox(height: 4),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Under the note: says when the category was picked from the note, or
/// offers the picked one when the user already chose another.
class _SmartCategoryHint extends StatelessWidget {
  // Category suggested from the note, if any.
  final String? suggestion;
  final String current;
  // True when the suggestion was applied automatically.
  final bool applied;
  final VoidCallback onApply;

  const _SmartCategoryHint({
    required this.suggestion,
    required this.current,
    required this.applied,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textSecondary = palette.textSecondary;
    final colors = smartGlowColors(context);
    final label = suggestion;

    Widget? child;
    // Applied automatically: a short confirmation line.
    if (label != null && applied) {
      child = Row(
        key: ValueKey('applied-$label'),
        children: [
          const SmartSpark(size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'اخترتُ تصنيف «$label» من الملاحظة',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: const ['Tajawal'],
                fontSize: 12.5,
                color: textSecondary,
              ),
            ),
          ),
        ],
      );
      // User picked something else: offer the suggestion as a chip.
    } else if (label != null && label != current) {
      child = Align(
        key: ValueKey('offer-$label'),
        alignment: AlignmentDirectional.centerStart,
        child: ActionChip(
          avatar: const SmartSpark(size: 22),
          label: Text(
            'اقتراح: $label',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: onApply,
          shape: const StadiumBorder(),
          side: BorderSide(color: colors[2].withValues(alpha: 0.35)),
          backgroundColor: colors[2].withValues(alpha: 0.08),
        ),
      );
    }

    return AnimatedSize(
      duration: AppMotion.sizeOf(context, AppMotion.medium),
      curve: AppMotion.enter,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.fast),
        child: child == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: child.key,
                padding: const EdgeInsets.only(top: 8),
                child: child,
              ),
      ),
    );
  }
}
