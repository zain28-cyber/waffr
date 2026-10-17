// Moves money from savings back into the operating balance.

import 'package:flutter/material.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/core/theme/app_motion.dart';

/// Opens the sheet that moves an amount from savings back into the balance.
Future<void> showWithdrawSavingsSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => const _WithdrawSavingsSheet(),
  );
}

/// Amount form that transfers from savings back to balance, capped at the
/// savings held in the chosen currency.
class _WithdrawSavingsSheet extends StatefulWidget {
  const _WithdrawSavingsSheet();

  @override
  State<_WithdrawSavingsSheet> createState() => _WithdrawSavingsSheetState();
}

/// State of [_WithdrawSavingsSheet]. Owns the amount controller and the
/// chosen currency.
class _WithdrawSavingsSheetState extends State<_WithdrawSavingsSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TransactionStore _store = TransactionStore.instance;

  /// True while the transfer is in flight; blocks double submits.
  bool _saving = false;
  late String _currencyCode;

  double get _amount => parseAmount(_amountController.text);

  bool get _isValid =>
      _amount > 0 && _amount <= _store.savingsBalanceFor(_currencyCode);

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
    super.dispose();
  }

  /// Credits balance and debits savings for the entered amount, then closes
  /// the sheet on success.
  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);

    final ok = await _store.withdrawFromSavings(
      _amount,
      currencyCode: _currencyCode,
    );
    if (!mounted) return;
    if (ok) {
      AppHaptics.success();
      Navigator.of(context).maybePop();
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheetBody(
      children: [
        GlassSheetHeader(
          title: 'سحب إلى الرصيد',
          subtitle: 'يُعاد المبلغ من التوفير إلى رصيدك.',
          onNext: _isValid ? _save : null,
        ),
        const SizedBox(height: 18),
        SheetAmountField(
          label: 'المبلغ',
          controller: _amountController,
          helper:
              'الموفَّر ${formatMoney(_store.savingsBalanceFor(_currencyCode))} ${currencyLabelFor(_currencyCode)}',
          currencyCode: _currencyCode,
          onCurrencyChanged: (code) => setState(() => _currencyCode = code),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 22),
        SheetSaveButton(
          label: 'تأكيد السحب',
          enabled: _isValid && !_saving,
          onTap: _save,
        ),
      ],
    );
  }
}
