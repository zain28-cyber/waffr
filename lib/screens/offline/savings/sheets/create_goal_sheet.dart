// Bottom sheet to create a named savings goal with percent, fixed, or custom
// funding, previewing how many periods the target will take.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/widgets/sheets/monthly_income_required_sheet.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Opens the create-goal sheet. Opened from the savings screen and from the
/// manage-goals sheet.
Future<void> showCreateGoalSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => const _CreateGoalSheet(),
  );
}

/// Form sheet: name, target, and contribution method for a new goal.
class _CreateGoalSheet extends StatefulWidget {
  const _CreateGoalSheet();

  @override
  State<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

/// How each income period contributes toward the goal target.
enum _ContributionType { percent, fixed, custom }

/// State of [_CreateGoalSheet]. Owns the four text controllers (each
/// rebuilds the form on change) and the chosen method and currency.
class _CreateGoalSheetState extends State<_CreateGoalSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _percentController = TextEditingController();
  final TextEditingController _fixedAmountController = TextEditingController();

  final TransactionStore _store = TransactionStore.instance;

  /// True while the goal is being saved; blocks double submits.
  bool _saving = false;
  late _ContributionType _type;
  late String _currencyCode;

  /// Upper bound for the target and fixed amounts.
  static const double _maxAmount = 999999999;

  double get _target => parseAmount(_targetController.text);

  double get _fixedAmount => parseAmount(_fixedAmountController.text);

  /// Income frequency used for periodic goals in the chosen currency.
  RecurringFrequency get _frequency =>
      _store.preferredIncomeFrequencyFor(_currencyCode);

  /// Reference income per period: the configured monthly income, or the
  /// store's reference for weekly income.
  double get _income {
    if (_frequency == RecurringFrequency.monthly) {
      return _store.configuredMonthlyIncomeFor(_currencyCode) ?? 0;
    }
    return _store.referenceIncome(_frequency, currencyCode: _currencyCode);
  }

  bool get _isCustom => _type == _ContributionType.custom;

  int get _percent {
    final value = int.tryParse(_percentController.text.trim()) ?? 0;

    return value.clamp(0, 100);
  }

  /// Amount set aside each period (0 for custom goals), capped at the income.
  double get _periodAmount {
    if (_isCustom) {
      return 0;
    }

    if (_type == _ContributionType.fixed) {
      return _capToIncome(_fixedAmount);
    }

    if (_percent <= 0 || _income <= 0) {
      return 0;
    }

    return _capToIncome(_income * _percent / 100);
  }

  /// A periodic contribution cannot be larger than the reference salary.
  double _capToIncome(double amount) {
    if (_income > 0 && amount > _income) {
      return _income;
    }
    return amount;
  }

  /// Periods needed to reach the target at [_periodAmount].
  int get _requiredPeriods {
    if (_isCustom || _target <= 0 || _periodAmount <= 0) {
      return 0;
    }

    return (_target / _periodAmount).ceil();
  }

  /// Total collected after [_requiredPeriods]; may slightly exceed the target.
  double get _expectedAmount {
    if (_requiredPeriods <= 0) {
      return 0;
    }

    return _periodAmount * _requiredPeriods;
  }

  /// Whether the form can be saved; percent and fixed need a known income.
  bool get _isValid {
    if (_nameController.text.trim().isEmpty) {
      return false;
    }

    if (_target <= 0 || _target > _maxAmount) {
      return false;
    }

    if (_isCustom) {
      return true;
    }

    if (_income <= 0) {
      return false;
    }

    if (_type == _ContributionType.fixed) {
      return _fixedAmount > 0 &&
          _fixedAmount <= _maxAmount &&
          (_income <= 0 || _fixedAmount <= _income);
    }

    return _percent > 0;
  }

  /// Label for the percent tile's period.
  String get _frequencyTitle {
    return _frequency == RecurringFrequency.weekly ? 'أسبوعي' : 'شهري';
  }

  /// Singular noun for one income period.
  String get _periodSingular {
    return _frequency == RecurringFrequency.weekly ? 'أسبوع' : 'شهر';
  }

  @override
  void initState() {
    super.initState();
    _currencyCode = CurrencyStore.instance.activeCode;

    // Default to percent when income is known; re-check once the store loads.
    _type = _income > 0 ? _ContributionType.percent : _ContributionType.custom;

    _store.ensureLoaded().then((_) {
      if (!mounted) return;

      setState(() {
        if (_income <= 0) {
          _type = _ContributionType.custom;
        }
      });
    });

    _nameController.addListener(_refresh);
    _targetController.addListener(_refresh);
    _percentController.addListener(_refresh);
    _fixedAmountController.addListener(_refresh);
  }

  /// Rebuilds the form when any controller changes.
  void _refresh() {
    if (!mounted) return;

    setState(() {});
  }

  /// Blocks percent/fixed funding until monthly income is configured, and
  /// clears the other method's field when switching.
  void _switchMethod(_ContributionType type) {
    if (_type == type) {
      return;
    }

    if (type != _ContributionType.custom && _income <= 0) {
      showMonthlyIncomeRequiredSheet(context);
      return;
    }

    setState(() {
      _type = type;

      if (type == _ContributionType.fixed) {
        _percentController.clear();
      } else if (type == _ContributionType.percent) {
        _fixedAmountController.clear();
      }
    });
  }

  /// Persists the goal with contribution rules derived from the selected
  /// method, then closes the sheet on success.
  Future<void> _save() async {
    if (!_isValid || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final periods = _isCustom ? null : _requiredPeriods;

    final duration = _isCustom
        ? GoalDurationPreset.year
        : GoalDurationPresetLabel.fromCount(
            periods ?? 1,
            frequency: _frequency,
          );

    final success = await _store.createGoal(
      name: _nameController.text.trim(),
      targetAmount: _target,
      duration: duration,
      allocatePercent: _type == _ContributionType.percent
          ? _percent.toDouble()
          : null,
      allocateAmount: _isCustom ? null : _periodAmount,
      deductFrequency: _isCustom ? RecurringFrequency.none : _frequency,
      isPeriodic: !_isCustom,
      durationCount: periods,
      currencyCode: _currencyCode,
    );

    if (!mounted) return;

    if (success) {
      AppHaptics.success();
      Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _saving = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _percentController.dispose();
    _fixedAmountController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final colors = _GoalColors(
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      accent: palette.accent,
    );

    return GlassSheetBody(
      children: [
        GlassSheetHeader(
          title: 'إنشاء هدف',
          subtitle: 'حدّد هدفك واختر طريقة التوفير.',
          onNext: _isValid && !_saving ? _save : null,
        ),

        const SizedBox(height: 18),

        // Name and target amount.
        const SheetFieldLabel(text: 'اسم الهدف'),

        SheetTextField(
          controller: _nameController,
          hint: 'مثال: صندوق الطوارئ',
        ),

        const SizedBox(height: 18),

        SheetAmountField(
          label: 'المبلغ المستهدف',
          controller: _targetController,
          currencyCode: _currencyCode,
          onCurrencyChanged: (code) => setState(() => _currencyCode = code),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 20),

        // Funding method tiles.
        Text(
          'نوع الخطة',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontFamilyFallback: ['Tajawal'],
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _MethodButton(
                title: 'نسبة من الدخل',
                subtitle: _frequencyTitle,
                selected: _type == _ContributionType.percent,
                onTap: () => _switchMethod(_ContributionType.percent),
                colors: colors,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MethodButton(
                title: 'مبلغ ثابت',
                subtitle: 'كل $_periodSingular',
                selected: _type == _ContributionType.fixed,
                onTap: () => _switchMethod(_ContributionType.fixed),
                colors: colors,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MethodButton(
                title: 'مبلغ مخصص',
                subtitle: 'يدوي',
                selected: _isCustom,
                onTap: () => _switchMethod(_ContributionType.custom),
                colors: colors,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Method-specific fields: percent, fixed amount, or the custom note.
        SheetSwap(
          switchKey: _type,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_type == _ContributionType.percent) ...[
                const SheetFieldLabel(text: 'نسبة التوفير'),
                Stack(
                  children: [
                    SheetTextField(
                      controller: _percentController,
                      hint: 'مثال: 10',
                      keyboardType: TextInputType.number,
                      inputFormatters: const [_SavingsPercentFormatter()],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 25, top: 18),
                          child: Text(
                            "%",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'الدخل المرجعي: '
                  '${formatMoney(_income)} '
                  '${currencyLabelFor(_currencyCode)} / $_periodSingular',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ] else if (_type == _ContributionType.fixed) ...[
                SheetFieldLabel(text: 'مبلغ التوفير كل $_periodSingular'),
                Stack(
                  children: [
                    SheetTextField(
                      controller: _fixedAmountController,
                      hint: 'مثال: 100000',
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsInputFormatter()],
                      onChanged: (_) => setState(() {}),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 25, top: 18),
                          child: Text(
                            currencyLabelFor(_currencyCode),
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontFamilyFallback: ['Tajawal'],
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_income > 0 && _fixedAmount > _income) ...[
                  const SizedBox(height: 8),
                  Text(
                    'لا يمكن أن يتجاوز مبلغ التوفير الدخل.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: ['Tajawal'],
                      fontSize: 12,
                      color: colors.accent,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'سيتم اقتطاع هذا المبلغ من الدخل كل '
                  '$_periodSingular.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ] else
                Text(
                  'التوفير هنا ليس تلقائياً. انقل المبلغ بنفسك من رصيدك إلى الهدف متى شئت عبر «توفير مبلغ».',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                    fontSize: 12,
                    height: 1.5,
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),

        // Plan preview for periodic methods.
        SheetExpand(
          visible: !_isCustom && _periodAmount > 0 && _target > 0,
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: _GoalPreview(
              target: _target,
              periodAmount: _periodAmount,
              periods: _requiredPeriods,
              expected: _expectedAmount,
              frequency: _frequency,
              currencyCode: _currencyCode,
              colors: colors,
            ),
          ),
        ),

        const SizedBox(height: 22),

        SheetSaveButton(
          label: 'حفظ الهدف',
          enabled: _isValid && !_saving,
          onTap: _save,
        ),
      ],
    );
  }
}

/// Digits only. One or two digits stay as typed. Three digits, or any
/// value above 100, snaps the field to exactly 100.
class _SavingsPercentFormatter extends TextInputFormatter {
  const _SavingsPercentFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final value = int.tryParse(digits) ?? 0;
    final text = digits.length >= 3 || value > 100 ? '100' : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Selectable funding method tile (percent / fixed / custom).
class _MethodButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final _GoalColors colors;

  const _MethodButton({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.medium),
        curve: AppMotion.enter,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.12)
              : colors.textPrimary.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? colors.accent.withValues(alpha: 0.45)
                : colors.textPrimary.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? colors.accent : colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
                fontSize: 10.5,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the per-period amount, periods needed and expected total before
/// the user confirms.
class _GoalPreview extends StatelessWidget {
  final double target;
  final double periodAmount;
  final int periods;
  final double expected;
  final RecurringFrequency frequency;
  final String currencyCode;
  final _GoalColors colors;

  const _GoalPreview({
    required this.target,
    required this.periodAmount,
    required this.periods,
    required this.expected,
    required this.frequency,
    required this.currencyCode,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final periodSingular = frequency == RecurringFrequency.weekly
        ? 'أسبوع'
        : 'شهر';

    final periodPlural = frequency == RecurringFrequency.weekly
        ? 'أسابيع'
        : 'أشهر';

    final durationText = periods == 1
        ? '$periodSingular واحد'
        : '$periods $periodPlural';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Text(
            'معاينة الخطة',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '${formatMoney(periodAmount)} '
            '${currencyLabelFor(currencyCode)} / $periodSingular',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.accent,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'المدة المتوقعة: $durationText',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 12,
              color: colors.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'المجموع المتوقع: '
            '${formatMoney(expected)} ${currencyLabelFor(currencyCode)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 11.5,
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            'الهدف: ${formatMoney(target)} ${currencyLabelFor(currencyCode)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Local light/dark color snapshot for this sheet.
class _GoalColors {
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const _GoalColors({
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });
}
