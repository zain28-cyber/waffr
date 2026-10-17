// Create or inspect the automatic percent-of-income savings plan: a picker
// with a confirm preview, or the details of the plan already running.

import 'package:flutter/material.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/widgets/sheets/monthly_income_required_sheet.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Opens the periodic plan sheet. Without a configured monthly income it
/// shows the income-required sheet instead; with an active plan it shows
/// that plan's details rather than the picker.
Future<void> showPeriodicGoalsSheet(BuildContext context) async {
  await TransactionStore.instance.ensureLoaded();
  if (!context.mounted) return;
  if (!TransactionStore.instance.hasConfiguredMonthlyIncome) {
    await showMonthlyIncomeRequiredSheet(context);
    return;
  }

  final plan = TransactionStore.instance.activePeriodicGoal;

  return showGlassSheet<void>(
    context: context,
    builder: (context) => plan == null
        ? const _PeriodicGoalsSheet()
        : _PeriodicPlanDetailsSheet(goal: plan),
  );
}

/// Percent + duration picker, then a confirm preview before applying the plan.
class _PeriodicGoalsSheet extends StatefulWidget {
  const _PeriodicGoalsSheet();

  @override
  State<_PeriodicGoalsSheet> createState() => _PeriodicGoalsSheetState();
}

/// State of [_PeriodicGoalsSheet]. Tracks the chosen percent and duration
/// and whether the preview step is showing.
class _PeriodicGoalsSheetState extends State<_PeriodicGoalsSheet> {
  /// Percent choices offered as chips.
  static const List<int> _percents = [5, 10, 15, 20];

  /// Duration choices offered as chips.
  static const List<GoalDurationPreset> _durations = [
    GoalDurationPreset.threeMonths,
    GoalDurationPreset.sixMonths,
    GoalDurationPreset.year,
  ];

  final TransactionStore _store = TransactionStore.instance;

  int _percent = 10;
  GoalDurationPreset _duration = GoalDurationPreset.sixMonths;

  /// True on the confirm step.
  bool _preview = false;

  /// True while the plan is being written.
  bool _saving = false;

  /// Plans always deduct monthly.
  RecurringFrequency get _frequency => RecurringFrequency.monthly;

  double get _income => _store.configuredMonthlyIncome ?? 0;

  /// Deduction per period at the chosen percent.
  double get _perPeriod => _income * _percent / 100;

  /// Number of deductions over the chosen duration.
  int get _cycles => _duration.cycleCount(_frequency);

  /// Total the plan will collect; becomes the goal target.
  double get _expected => _perPeriod * _cycles;

  /// Whether the plan would collect anything.
  bool get _isMeaningful => _income > 0 && _perPeriod > 0 && _expected > 0;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Writes the periodic plan into the store and closes on success.
  Future<void> _confirm() async {
    if (!_isMeaningful || _saving) return;
    setState(() => _saving = true);

    final ok = await _store.applyPeriodicPlan(
      percent: _percent.toDouble(),
      duration: _duration,
      frequency: _frequency,
      income: _income,
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
          title: _preview ? 'معاينة الخطة' : 'خطط التوفير الدورية',
          subtitle: _preview
              ? 'راجع النتيجة قبل التأكيد.'
              : 'اختر النسبة والمدة حسب دخلك.',
          onNext: _preview
              ? (_isMeaningful ? _confirm : null)
              : (_isMeaningful ? () => setState(() => _preview = true) : null),
        ),
        const SizedBox(height: 18),
        SheetSwap(
          switchKey: _preview,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _preview ? _buildPreview(context) : _buildPicker(context),
          ),
        ),
        const SizedBox(height: 22),
        SheetSaveButton(
          label: _preview ? 'تأكيد الخطة' : 'معاينة الخطة',
          enabled: _isMeaningful && !_saving,
          onTap: _preview ? _confirm : () => setState(() => _preview = true),
        ),
      ],
    );
  }

  /// Picker step: reference income, percent chips and duration chips.
  List<Widget> _buildPicker(BuildContext context) {
    final palette = AppPalette.of(context);
    final textSecondary = palette.textSecondary;

    if (_income <= 0) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Text(
            'أضف دخلاً شهرياً أولاً لاقتراح خطط مناسبة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 14,
              color: textSecondary,
            ),
          ),
        ),
      ];
    }

    return [
      SheetFieldLabel(
        text: _frequency == RecurringFrequency.weekly
            ? 'الدخل الأسبوعي المعتمد'
            : 'الدخل الشهري المعتمد',
      ),
      Text(
        '${formatMoney(_income)} $currencyLabel',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontFamilyFallback: ['Tajawal'],
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: palette.accent,
        ),
      ),
      const SizedBox(height: 18),
      const SheetFieldLabel(text: 'نسبة التوفير'),
      SheetChoiceChips(
        options: _percents.map((item) => '$item٪').toList(),
        selected: '$_percent٪',
        onSelected: (value) {
          setState(() {
            _percent = int.tryParse(value.replaceAll('٪', '')) ?? 10;
          });
        },
      ),
      const SizedBox(height: 18),
      const SheetFieldLabel(text: 'المدة'),
      SheetChoiceChips(
        options: _durations.map((item) => item.label).toList(),
        selected: _duration.label,
        onSelected: (value) {
          setState(() {
            _duration = _durations.firstWhere((item) => item.label == value);
          });
        },
      ),
    ];
  }

  /// Preview step: income, percent, per-period deduction, duration and total.
  List<Widget> _buildPreview(BuildContext context) {
    final palette = AppPalette.of(context);
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;
    final periodWord = _frequency == RecurringFrequency.weekly
        ? 'أسبوعياً'
        : 'شهرياً';

    return [
      GlassContainer(
        colorType: GlassColorType.surface,
        borderRadius: 22,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          children: [
            _PreviewRow(
              label: _frequency == RecurringFrequency.weekly
                  ? 'الدخل الأسبوعي'
                  : 'الدخل الشهري',
              value: '${formatMoney(_income)} $currencyLabel',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _PreviewRow(
              label: 'نسبة التوفير',
              value: '$_percent٪',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _PreviewRow(
              label: 'الاقتطاع $periodWord',
              value: '${formatMoney(_perPeriod)} $currencyLabel',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _PreviewRow(
              label: 'المدة',
              value: _duration.label,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _PreviewRow(
              label: 'المبلغ المستهدف',
              value: '${formatMoney(_expected)} $currencyLabel',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              emphasize: true,
            ),
          ],
        ),
      ),
    ];
  }
}

/// Label/value row used in the plan preview and the plan details.
class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;
  final bool emphasize;

  const _PreviewRow({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
                fontSize: 13.5,
                color: textSecondary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
                fontSize: emphasize ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only view of the active periodic plan with an option to delete it.
class _PeriodicPlanDetailsSheet extends StatefulWidget {
  final SavingsGoal goal;

  const _PeriodicPlanDetailsSheet({required this.goal});

  @override
  State<_PeriodicPlanDetailsSheet> createState() =>
      _PeriodicPlanDetailsSheetState();
}

/// State of [_PeriodicPlanDetailsSheet].
class _PeriodicPlanDetailsSheetState extends State<_PeriodicPlanDetailsSheet> {
  final TransactionStore _store = TransactionStore.instance;

  /// True while the delete is in flight; disables the button.
  bool _deleting = false;

  /// Asks for confirmation, deletes the plan's goal, and closes on success.
  Future<void> _confirmDelete() async {
    if (_deleting) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'حذف الخطة',
      message: 'هل أنت متأكد من حذف هذه الخطة الدورية؟',
      confirmLabel: 'حذف',
      destructive: true,
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final deleted = await _store.deleteGoal(widget.goal.id);
    if (!mounted) return;
    if (deleted) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _deleting = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;
    final periodWord = switch (widget.goal.deductFrequency) {
      RecurringFrequency.weekly => 'أسبوعياً',
      RecurringFrequency.monthly => 'شهرياً',
      RecurringFrequency.none => 'بدون تكرار',
    };
    final percent = widget.goal.allocatePercent;
    final amount = widget.goal.allocateAmount;

    return GlassSheetBody(
      children: [
        const GlassSheetHeader(
          title: 'الخطة الجارية',
          subtitle: 'تفاصيل الخطة الدورية المحفوظة.',
        ),
        const SizedBox(height: 18),
        GlassContainer(
          colorType: GlassColorType.surface,
          borderRadius: 22,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            children: [
              _PreviewRow(
                label: 'الاسم',
                value: widget.goal.name,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              if (percent != null && percent > 0)
                _PreviewRow(
                  label: 'نسبة التوفير',
                  value: '${percent.round()}٪',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              if (amount != null && amount > 0)
                _PreviewRow(
                  label: 'الاقتطاع $periodWord',
                  value: '${formatMoney(amount)} $currencyLabel',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              _PreviewRow(
                label: 'التكرار',
                value: periodWord,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _PreviewRow(
                label: 'المدة',
                value: widget.goal.duration.label,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _PreviewRow(
                label: 'المبلغ المستهدف',
                value:
                    '${formatMoney(widget.goal.targetAmount)} $currencyLabel',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SheetDestructiveButton(
          label: 'حذف الخطة',
          onTap: _deleting ? null : _confirmDelete,
        ),
      ],
    );
  }
}
