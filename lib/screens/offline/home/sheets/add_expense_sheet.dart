// Add-expense bottom sheet: one-off or recurring expenses, presets, a smart
// category suggestion from the note, and the category grid (part file).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/expense_preset_store.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/data/models/expense_preset.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/theme/app_color.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/screens/offline/home/sheets/expense_presets_dialog.dart';
import 'package:waffr/screens/offline/obligations/obligations_sheet.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/widgets/dialogs/edit_delete_menu.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/insights/smart/category_suggester.dart';
import 'package:waffr/data/services/smart_settings.dart';
import 'package:waffr/widgets/smart/smart_glow.dart';
import 'package:waffr/core/theme/app_palette.dart';

part 'expense_category_grid.dart';

/// Opens the add-expense sheet. A one-off expense is saved to
/// [TransactionStore]; a recurring one becomes an obligation in
/// [RecurringExpenseStore].
Future<void> showAddExpenseSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => const _AddExpenseSheet(),
  );
}

/// Form for a new expense; see [showAddExpenseSheet].
class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet();

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

/// State of [_AddExpenseSheet]. Owns the amount, note and interval
/// controllers and the debounce timer for smart category suggestions.
class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _category = CategoryStore.instance.defaultLabel;

  /// Smart category: picked from the note until the user chooses one
  /// themselves, after which it is only offered as a suggestion.
  bool _categoryTouched = false;
  // Last category suggested from the note, if any.
  String? _suggestedCategory;
  // Debounces note typing before asking the suggester.
  Timer? _suggestTimer;
  // Built lazily from the ledger on the first suggestion.
  CategorySuggester? _suggester;
  final String _paymentMethod = paymentMethods.first;

  bool _saving = false;
  bool _recurring = false;

  /// Star filled: the expense is also kept as a preset once it is saved.
  bool _saveAsPreset = false;

  /// Multiplies the entered amount (x1-x10) before saving.
  int _multiplier = 1;
  late String _currencyCode;
  RecurringUnit _recurringUnit = RecurringUnit.month;

  /// Null until the user picks; then the default follows the monthly income.
  bool? _confirmChoice;
  // Repeat every N units for recurring expenses.
  final TextEditingController _intervalController = TextEditingController(
    text: '1',
  );

  // Labels of the one-off / recurring choice chips.
  static const String _onceLabel = 'مرة واحدة';
  static const String _recurringLabel = 'مصروف متكرر';

  /// Typing in these fields only rebuilds what depends on the typed values
  /// (see build); the category grid is built once per state change.
  late final Listenable _typedFields = Listenable.merge([
    _amountController,
    _intervalController,
  ]);

  /// Amount as typed, before the multiplier.
  double get _enteredAmount => parseAmount(_amountController.text);

  /// Amount that will be saved: typed amount times the multiplier.
  double get _amount => _enteredAmount * _multiplier;

  /// Fixed salary -> automatic; no monthly income set -> ask before deducting.
  bool get _requiresConfirmation =>
      _confirmChoice ??
      !TransactionStore.instance.hasConfiguredMonthlyIncomeFor(_currencyCode);

  /// Typed repeat interval; 0 when empty or not a number.
  int get _intervalCount {
    final value = int.tryParse(_intervalController.text.trim()) ?? 0;
    return value;
  }

  /// Reads the balance once and checks the typed values against it.
  _ExpenseInputCheck _check() {
    return _ExpenseInputCheck(
      amount: _amount,
      multiplier: _multiplier,
      recurring: _recurring,
      intervalCount: _intervalCount,
      available: TransactionStore.instance.balanceFor(_currencyCode),
      currencySymbol: currencyLabelFor(_currencyCode),
    );
  }

  @override
  void initState() {
    super.initState();
    _currencyCode = CurrencyStore.instance.activeCode;
    TransactionStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    ExpensePresetStore.instance.ensureLoaded();
    CategoryStore.instance.ensureLoaded().then((_) {
      if (!mounted) return;
      final store = CategoryStore.instance;
      if (!store.isSelectable(_category)) {
        setState(() => _category = store.defaultLabel);
      }
    });
  }

  /// Waits for a pause in typing, then picks (or offers) a category.
  void _onNoteChanged(String note) {
    _suggestTimer?.cancel();
    _suggestTimer = Timer(const Duration(milliseconds: 280), () async {
      await SmartSettings.instance.ensureLoaded();
      if (!mounted || !SmartSettings.instance.categorize) return;
      _suggester ??= CategorySuggester(TransactionStore.instance.transactions);
      final options = [
        for (final item in CategoryStore.instance.selectableCategories)
          item.label,
      ];
      final suggestion = _suggester!.suggest(note, options);
      setState(() {
        _suggestedCategory = suggestion;
        if (suggestion != null && !_categoryTouched) _category = suggestion;
      });
    });
  }

  /// Star: pick a saved expense, or mark this one to be saved as a preset.
  Future<void> _openPresets() async {
    FocusScope.of(context).unfocus();
    final choice = await showExpensePresetsDialog(
      context,
      marked: _saveAsPreset,
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case ExpensePresetMark():
        setState(() => _saveAsPreset = true);
      case ExpensePresetUnmark():
        setState(() => _saveAsPreset = false);
      case ExpensePresetSelected(:final preset):
        await _applyPreset(preset);
    }
  }

  /// Fills every field from [preset]; the user can still edit before saving.
  Future<void> _applyPreset(ExpensePreset preset) async {
    final recurring = preset.recurring;
    final code =
        CurrencyStore.instance.enabledCodes.contains(preset.currencyCode)
        ? preset.currencyCode
        : _currencyCode;

    final note = preset.note ?? '';
    setState(() {
      _amountController.text = formatMoney(preset.amount);
      _multiplier = preset.multiplier;
      _currencyCode = code;
      _category = preset.category;
      _categoryTouched = true;
      _suggestedCategory = null;
      _noteController.text = note;
      _recurring = recurring;
      _recurringUnit = preset.unit;
      _intervalController.text = '${preset.intervalCount}';
      _saveAsPreset = false;
    });
  }

  /// Saves the current form as an [ExpensePreset] when the star is filled.
  Future<void> _storePresetIfMarked(String note) async {
    if (!_saveAsPreset) return;
    await ExpensePresetStore.instance.add(
      ExpensePreset(
        id: ExpensePreset.newId(),
        amount: _enteredAmount,
        multiplier: _multiplier,
        currencyCode: _currencyCode,
        category: _category,
        paymentMethod: _paymentMethod,
        note: note.isEmpty ? null : note,
        recurring: _recurring,
        unit: _recurringUnit,
        intervalCount: _recurring ? _intervalCount : 1,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _suggestTimer?.cancel();
    _noteController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  /// One-off goes to TransactionStore; recurring becomes an obligation.
  Future<void> _save() async {
    if (!_check().isValid || _saving) return;

    setState(() => _saving = true);

    final note = _noteController.text.trim();

    // Recurring: store an obligation; balance is not checked here.
    if (_recurring) {
      await RecurringExpenseStore.instance.addExpense(
        amount: _amount,
        category: _category,
        paymentMethod: _paymentMethod,
        unit: _recurringUnit,
        intervalCount: _intervalCount,
        note: note.isEmpty ? null : note,
        currencyCode: _currencyCode,
        requiresConfirmation: _requiresConfirmation,
      );
      await _storePresetIfMarked(note);

      if (!mounted) return;
      AppHaptics.success();
      Navigator.of(context).maybePop();
      return;
    }

    // One-off: the store returns null when the balance is too low.
    final added = await TransactionStore.instance.addExpense(
      amount: _amount,
      category: _category,
      paymentMethod: _paymentMethod,
      note: note.isEmpty ? null : note,
      currencyCode: _currencyCode,
    );

    if (!mounted) return;

    if (added == null) {
      setState(() => _saving = false);
      showInsufficientBalanceMessage(context);
      return;
    }

    await _storePresetIfMarked(note);
    if (!mounted) return;
    AppHaptics.success();
    Navigator.of(context).maybePop();
  }

  /// Manual category pick; stops smart suggestions from overriding it.
  void _pickCategory(String label) {
    setState(() {
      _category = label;
      _categoryTouched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Built here, outside the builder below, so typing reuses this instance
    // and Flutter skips rebuilding the grid and its tiles.
    final categoryGrid = ExpenseCategoryGrid(
      selected: _category,
      onSelected: _pickCategory,
    );

    return ListenableBuilder(
      listenable: _typedFields,
      builder: (context, _) => _buildBody(_check(), categoryGrid),
    );
  }

  /// Sheet content, rebuilt on every keystroke in the amount/interval fields.
  Widget _buildBody(_ExpenseInputCheck check, Widget categoryGrid) {
    return GlassSheetBody(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      children: [
        // Header, then amount with currency, multiplier and preset star.
        GlassSheetHeader(
          title: 'إضافة مصروف',
          subtitle: 'أدخل المبلغ واختر التصنيف.',
          onNext: check.isValid ? _save : null,
        ),
        const SizedBox(height: 10),
        SheetAmountField(
          label: 'المبلغ',
          controller: _amountController,
          helper: check.helper,
          currencyCode: _currencyCode,
          onCurrencyChanged: (code) => setState(() => _currencyCode = code),
          multiplier: _multiplier,
          onMultiplierChanged: (value) => setState(() => _multiplier = value),
          multiplierAccessory: _PresetStarButton(
            filled: _saveAsPreset,
            onTap: _openPresets,
          ),
        ),
        const SizedBox(height: 10),
        // One-off vs recurring, with the recurring options expanding below.
        const SheetFieldLabel(text: 'نوع المصروف'),
        SheetChoiceChips(
          options: const [_onceLabel, _recurringLabel],
          selected: _recurring ? _recurringLabel : _onceLabel,
          onSelected: (value) {
            setState(() => _recurring = value == _recurringLabel);
          },
        ),
        SheetExpand(
          visible: _recurring,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const SheetFieldLabel(text: 'التكرار'),
              SheetChoiceChips(
                options: const ['يوم', 'أسبوع', 'شهر'],
                selected: _recurringUnit.label,
                onSelected: (value) {
                  setState(() {
                    _recurringUnit = switch (value) {
                      'أسبوع' => RecurringUnit.week,
                      'شهر' => RecurringUnit.month,
                      _ => RecurringUnit.day,
                    };
                  });
                },
              ),
              const SizedBox(height: 10),
              SheetFieldLabel(text: 'كل كم ${_recurringUnit.label}؟'),
              SheetTextField(
                controller: _intervalController,
                hint: 'مثال: 1',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
              ),
              const SizedBox(height: 10),
              const SheetFieldLabel(
                text: 'طريقة الخصم',
                action: SheetInfoButton(
                  title: kDeductModeInfoTitle,
                  message: kDeductModeInfoMessage,
                ),
              ),
              SheetChoiceChips(
                options: const [kDeductAutomaticLabel, kDeductConfirmLabel],
                selected: _requiresConfirmation
                    ? kDeductConfirmLabel
                    : kDeductAutomaticLabel,
                onSelected: (value) => setState(
                  () => _confirmChoice = value == kDeductConfirmLabel,
                ),
              ),
            ],
          ),
        ),
        // Category grid, note, and the smart suggestion under it.
        const SizedBox(height: 10),
        const SheetFieldLabel(text: 'التصنيف'),
        categoryGrid,
        const SizedBox(height: 10),
        const SheetFieldLabel(text: 'ملاحظة', optional: true),
        SheetTextField(
          controller: _noteController,
          hint: 'مثال: غداء، تاكسي، فاتورة إنترنت...',
          onChanged: _onNoteChanged,
        ),
        _SmartCategoryHint(
          suggestion: _suggestedCategory,
          current: _category,
          applied:
              _suggestedCategory != null &&
              !_categoryTouched &&
              _suggestedCategory == _category,
          onApply: () {
            final suggestion = _suggestedCategory;
            if (suggestion == null) return;
            AppHaptics.selection();
            setState(() => _category = suggestion);
          },
        ),
        const SizedBox(height: 12),
        SheetSaveButton(
          label: _recurring ? 'حفظ المصروف المتكرر' : 'حفظ المصروف',
          enabled: check.isValid && !_saving,
          onTap: _save,
        ),
      ],
    );
  }
}

/// The typed amount and interval checked against the balance, read once per
/// rebuild instead of by every getter that needs it.
class _ExpenseInputCheck {
  // Upper bound on a single expense amount.
  static const double maxAmount = 999999999;

  final double amount;
  final int multiplier;
  final bool recurring;
  final int intervalCount;
  final double available;
  final String currencySymbol;

  const _ExpenseInputCheck({
    required this.amount,
    required this.multiplier,
    required this.recurring,
    required this.intervalCount,
    required this.available,
    required this.currencySymbol,
  });

  /// One-off expenses cannot exceed the balance in that currency. Recurring
  /// bills are saved for later, so they are not blocked here.
  bool get exceedsBalance => !recurring && amount > 0 && amount > available;

  /// Whether the form can be saved: amount in range and, for recurring
  /// expenses, an interval of 1-99.
  bool get isValid {
    if (amount <= 0 || amount > maxAmount || exceedsBalance) return false;
    if (!recurring) return true;
    return intervalCount > 0 && intervalCount <= 99;
  }

  /// Under the amount: the balance when it is exceeded, else the total
  /// after the multiplier.
  String? get helper {
    if (exceedsBalance) {
      return 'أكبر من الرصيد المتاح ${formatMoney(available)} $currencySymbol';
    }
    if (multiplier == 1) return null;
    return 'الإجمالي ${formatMoney(amount)} $currencySymbol';
  }
}

/// Star above the multiplier button. Filled (accent green) once the expense is
/// marked to be kept as a preset.
class _PresetStarButton extends StatelessWidget {
  final bool filled;
  final VoidCallback onTap;

  const _PresetStarButton({required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = palette.accent;
    final textSecondary = palette.textSecondary;

    return Semantics(
      button: true,
      label: filled ? 'سيُحفظ كمصروف محفوظ' : 'المصروفات المحفوظة',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 36,
          height: 26,
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.medium),
            switchInCurve: AppMotion.overshoot,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_border_rounded,
              key: ValueKey(filled),
              size: 22,
              color: filled ? accent : textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
