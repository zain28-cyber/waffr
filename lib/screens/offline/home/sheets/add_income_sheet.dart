// Add-income bottom sheet: amount, frequency, what to do with the leftover
// balance, and an optional source. Offers to review waiting obligations after.

import 'package:flutter/material.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/screens/offline/obligations/obligations_sheet.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/core/theme/app_motion.dart';

/// Opens the add-income sheet. Saves through [TransactionStore.addIncome],
/// then may offer the due-obligations sheet if bills await confirmation.
Future<void> showAddIncomeSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => const _AddIncomeSheet(),
  );
}

/// Form for a new income; see [showAddIncomeSheet].
class _AddIncomeSheet extends StatefulWidget {
  const _AddIncomeSheet();

  @override
  State<_AddIncomeSheet> createState() => _AddIncomeSheetState();
}

/// State of [_AddIncomeSheet]. Owns the amount and source controllers.
class _AddIncomeSheetState extends State<_AddIncomeSheet> {
  // Frequency chip labels.
  static const String _freqNone = 'مرة واحدة';
  static const String _freqWeekly = 'أسبوعي';
  static const String _freqMonthly = 'شهري';

  /// Weekly income still works in the store; the chip is hidden for now.
  static const bool _weeklyIncomeChoiceEnabled = false;
  // Frequency chips actually shown.
  static const List<String> _frequencyOptions = [
    if (_weeklyIncomeChoiceEnabled) _freqWeekly,
    _freqMonthly,
    _freqNone,
  ];
  // Leftover-balance chip labels: keep it, or move it to savings.
  static const String _keepBalance = 'إبقاء الرصيد';
  static const String _moveBalance = 'نقل الرصيد للتوفير';

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();

  final TransactionStore _store = TransactionStore.instance;

  String _frequencyLabel = _freqNone;
  String _balanceAction = _keepBalance;
  bool _saving = false;
  late String _currencyCode;

  // Upper bound on a single income amount.
  static const double _maxAmount = 999999999;

  /// Typed amount.
  double get _amount => parseAmount(_amountController.text);

  /// Whether the amount is positive and within the limit.
  bool get _isValid => _amount > 0 && _amount <= _maxAmount;

  /// Store frequency for the selected chip.
  RecurringFrequency get _frequency => switch (_frequencyLabel) {
    _freqWeekly => RecurringFrequency.weekly,
    _freqMonthly => RecurringFrequency.monthly,
    _ => RecurringFrequency.none,
  };

  @override
  void initState() {
    super.initState();
    _currencyCode = CurrencyStore.instance.activeCode;
    _store.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  /// Saves the income, closes the sheet, then offers to review obligations
  /// that still wait for confirmation in this currency.
  Future<void> _save() async {
    if (!_isValid || _saving) return;

    setState(() => _saving = true);

    final source = _sourceController.text.trim();

    await _store.addIncome(
      amount: _amount,
      source: source.isEmpty ? null : source,
      frequency: _frequency,
      moveBalanceToSavings: _balanceAction == _moveBalance,
      currencyCode: _currencyCode,
    );

    // New income ends "remind me on next income" and is a good moment to
    // settle obligations that still wait for approval.
    final obligations = RecurringExpenseStore.instance;
    await obligations.releaseIncomeReminders(_currencyCode);
    final waiting = obligations.awaitingConfirmation(_currencyCode).isNotEmpty;

    if (!mounted) return;
    AppHaptics.success();
    // Pop first, then ask on the navigator's context (this sheet is gone).
    final navigator = Navigator.of(context);
    await navigator.maybePop();
    if (!waiting || !navigator.mounted) return;

    final review = await showAppConfirmDialog(
      navigator.context,
      title: 'التزامات بانتظار تأكيدك',
      message: 'أضفت دخلاً جديداً، ولديك التزامات لم تُخصم بعد. هل تريد مراجعتها الآن؟',
      confirmLabel: 'مراجعة',
      cancelLabel: 'لاحقاً',
      kind: AppFeedbackKind.info,
    );
    if (review && navigator.mounted) {
      await showDueObligationsSheet(navigator.context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The leftover-balance choice only appears when there is something left.
    final hasBalance = _store.balanceFor(_currencyCode) > 0;

    return GlassSheetBody(
      children: [
        GlassSheetHeader(
          title: 'إضافة دخل',
          subtitle: 'أدخل المبلغ ليضاف إلى رصيدك.',
          onNext: _isValid ? _save : null,
        ),
        const SizedBox(height: 18),
        // Amount with currency and the max-amount hint.
        SheetAmountField(
          label: 'مبلغ الدخل',
          controller: _amountController,
          helper:
              'الحد الأقصى ${formatMoney(_maxAmount)} ${currencyLabelFor(_currencyCode)}',
          currencyCode: _currencyCode,
          onCurrencyChanged: (code) => setState(() => _currencyCode = code),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        // Frequency, then the leftover-balance choice when relevant.
        const SheetFieldLabel(text: 'نوع الدخل'),
        SheetChoiceChips(
          options: _frequencyOptions,
          selected: _frequencyLabel,
          onSelected: (value) => setState(() => _frequencyLabel = value),
        ),
        SheetExpand(
          visible: hasBalance,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              SheetFieldLabel(
                text: 'الرصيد الحالي',
                action: const SheetInfoButton(
                  title: 'الرصيد الحالي',
                  message: 'هذا هو المبلغ المتبقي لديك من الفترة السابقة. اختر ما تريد فعله به: نقله إلى التوفير، أو إبقاءه ضمن رصيدك الجديد.',
                ),
              ),
              SheetChoiceChips(
                options: const [_keepBalance, _moveBalance],
                selected: _balanceAction,
                onSelected: (value) => setState(() => _balanceAction = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Optional source and the save button.
        const SheetFieldLabel(text: 'مصدر الدخل', optional: true),
        SheetTextField(
          controller: _sourceController,
          hint: 'مثال: راتب، عمل حر، تحويل...',
        ),
        const SizedBox(height: 22),
        SheetSaveButton(
          label: 'حفظ الدخل',
          enabled: _isValid && !_saving,
          onTap: _save,
        ),
      ],
    );
  }
}
