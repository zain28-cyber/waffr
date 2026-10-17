// Glass sheet for the monthly (or weekly) income amount, same shell as other
// sheets. It only returns the result; the caller saves it.

import 'package:flutter/material.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/widgets/dialogs/edit_amount_dialog.dart';

/// Opens the income editor as a sheet. Pops [EditAmountResult] (amount and
/// currency) or, when [allowClear] and the user taps remove,
/// [AmountDialogCleared]; null when dismissed.
Future<Object?> showMonthlyIncomeSheet(
  BuildContext context, {
  required String title,
  required double initialAmount,
  required bool allowClear,
}) {
  return showGlassSheet<Object>(
    context: context,
    builder: (context) => _MonthlyIncomeSheet(
      title: title,
      initialAmount: initialAmount,
      allowClear: allowClear,
    ),
  );
}

/// Amount + currency form with save and, optionally, a remove button.
class _MonthlyIncomeSheet extends StatefulWidget {
  final String title;
  final double initialAmount;
  final bool allowClear;

  const _MonthlyIncomeSheet({
    required this.title,
    required this.initialAmount,
    required this.allowClear,
  });

  @override
  State<_MonthlyIncomeSheet> createState() => _MonthlyIncomeSheetState();
}

/// State of [_MonthlyIncomeSheet]. Owns the amount controller, prefilled
/// with the current income.
class _MonthlyIncomeSheetState extends State<_MonthlyIncomeSheet> {
  /// Upper bound for the income amount.
  static const double _maxAmount = 999999999;

  late final TextEditingController _controller;
  late String _currencyCode;

  double get _amount => parseAmount(_controller.text);

  bool get _isValid => _amount > 0 && _amount <= _maxAmount;

  @override
  void initState() {
    super.initState();
    _currencyCode = CurrencyStore.instance.activeCode;
    _controller = TextEditingController(
      text: widget.initialAmount > 0 && widget.initialAmount.isFinite
          ? formatMoney(widget.initialAmount)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pops the entered amount and currency.
  void _save() {
    if (!_isValid) return;
    Navigator.of(context).pop(EditAmountResult(_amount, _currencyCode));
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheetBody(
      children: [
        GlassSheetHeader(
          title: widget.title,
          subtitle: 'يُستخدم لحساب خطط التوفير الدورية.',
          onNext: _isValid ? _save : null,
        ),
        const SizedBox(height: 18),
        SheetAmountField(
          label: 'المبلغ',
          controller: _controller,
          currencyCode: _currencyCode,
          onCurrencyChanged: (code) => setState(() => _currencyCode = code),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 22),
        SheetSaveButton(label: 'حفظ', enabled: _isValid, onTap: _save),
        if (widget.allowClear) ...[
          const SizedBox(height: 8),
          SheetDestructiveButton(
            label: 'إزالة الدخل',
            onTap: () =>
                Navigator.of(context).pop(AmountDialogCleared(_currencyCode)),
          ),
        ],
      ],
    );
  }
}
