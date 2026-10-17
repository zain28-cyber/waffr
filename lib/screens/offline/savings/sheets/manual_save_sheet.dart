// Moves money from the operating balance into savings without a goal.

import 'package:flutter/material.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/core/theme/app_motion.dart';

/// Opens the sheet that moves an amount from the balance into savings.
Future<void> showManualSaveSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => const _ManualSaveSheet(),
  );
}

/// Amount form that transfers from balance into savings, capped at the
/// balance available in the chosen currency.
class _ManualSaveSheet extends StatefulWidget {
  const _ManualSaveSheet();

  @override
  State<_ManualSaveSheet> createState() => _ManualSaveSheetState();
}

/// State of [_ManualSaveSheet]. Owns the amount controller and the chosen
/// currency.
class _ManualSaveSheetState extends State<_ManualSaveSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TransactionStore _store = TransactionStore.instance;

  /// True while the transfer is in flight; blocks double submits.
  bool _saving = false;
  late String _currencyCode;

  double get _amount => parseAmount(_amountController.text);

  bool get _isValid =>
      _amount > 0 && _amount <= _store.balanceFor(_currencyCode);

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

  /// Debits balance and credits savings for the entered amount, then closes
  /// the sheet on success.
  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);

    final ok = await _store.saveManually(_amount, currencyCode: _currencyCode);
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
          title: 'توفير مبلغ',
          subtitle: 'يُنقل المبلغ من رصيدك إلى التوفير.',
          onNext: _isValid ? _save : null,
        ),
        const SizedBox(height: 18),
        SheetAmountField(
          label: 'المبلغ',
          controller: _amountController,
          helper:
              'المتاح ${formatMoney(_store.balanceFor(_currencyCode))} ${currencyLabelFor(_currencyCode)}',
          currencyCode: _currencyCode,
          onCurrencyChanged: (code) => setState(() => _currencyCode = code),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 22),
        SheetSaveButton(
          label: 'تأكيد التوفير',
          enabled: _isValid && !_saving,
          onTap: _save,
        ),
      ],
    );
  }
}
