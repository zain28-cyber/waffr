// Date and date-range picker: a typed DD/MM/YYYY field above a calendar.
//
// Separators are added while typing, so the number pad is enough. The field
// and the calendar stay in sync: typing a full date moves the calendar to it,
// and tapping a day fills the field. Digits are 0-9 (see
// WaffrMaterialLocalizations).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/core/utils/date_input.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';

/// One date. Returns null when the user cancels.
Future<DateTime?> showWaffrDatePicker({
  required BuildContext context,
  required String title,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialDate,
  bool startWithYear = false,
}) async {
  final result = await showAppDialog<List<DateTime>>(
    context: context,
    builder: (_) => _WaffrDatePickerDialog(
      title: title,
      labels: const ['التاريخ'],
      initial: [initialDate],
      firstDate: firstDate,
      lastDate: lastDate,
      startWithYear: startWithYear && initialDate == null,
    ),
  );
  return result == null || result.isEmpty ? null : result.first;
}

/// A from/to range. Returns null when the user cancels.
Future<DateTimeRange?> showWaffrDateRangePicker({
  required BuildContext context,
  required String title,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialRange,
}) async {
  final result = await showAppDialog<List<DateTime>>(
    context: context,
    builder: (_) => _WaffrDatePickerDialog(
      title: title,
      labels: const ['من', 'إلى'],
      initial: [initialRange?.start, initialRange?.end],
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
  if (result == null || result.length != 2) return null;
  return DateTimeRange(start: result[0], end: result[1]);
}

/// The dialog behind both pickers: one typed field per date over a
/// calendar, the active field following the calendar taps.
class _WaffrDatePickerDialog extends StatefulWidget {
  final String title;
  final List<String> labels;
  final List<DateTime?> initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool startWithYear;

  const _WaffrDatePickerDialog({
    required this.title,
    required this.labels,
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    this.startWithYear = false,
  });

  @override
  State<_WaffrDatePickerDialog> createState() => _WaffrDatePickerDialogState();
}

/// State of [_WaffrDatePickerDialog].
class _WaffrDatePickerDialogState extends State<_WaffrDatePickerDialog> {
  late final List<DateTime?> _dates;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final DateTime _first = _dayOnly(widget.firstDate);
  late final DateTime _last = _dayOnly(widget.lastDate);

  int _active = 0;

  // Bumped when the calendar must jump to a date it did not pick itself.
  int _calendarVersion = 0;

  // Set while the calendar applies a year choice, which also reports a date.
  // That date only moves the calendar, so the range does not advance yet.
  bool _monthJump = false;

  bool get _isRange => widget.labels.length == 2;

  @override
  void initState() {
    super.initState();
    _dates = [
      for (final date in widget.initial)
        date == null || _outOfRange(_dayOnly(date)) ? null : _dayOnly(date),
    ];
    if (_isRange &&
        _dates[0] != null &&
        _dates[1] != null &&
        _dates[1]!.isBefore(_dates[0]!)) {
      _dates[1] = null;
    }
    _controllers = [
      for (final date in _dates)
        TextEditingController(text: date == null ? '' : formatDateInput(date)),
    ];
    _focusNodes = [
      for (var i = 0; i < _dates.length; i++)
        FocusNode()..addListener(() => _onFocus(i)),
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  static DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _outOfRange(DateTime day) => day.isBefore(_first) || day.isAfter(_last);

  void _onFocus(int index) {
    if (!_focusNodes[index].hasFocus || _active == index) return;
    setState(() {
      _active = index;
      _calendarVersion++;
    });
  }

  void _activate(int index) {
    if (_active == index) return;
    setState(() {
      _active = index;
      _calendarVersion++;
    });
  }

  String? _errorFor(int index) {
    final text = _controllers[index].text;
    final error = dateInputError(text, firstDate: _first, lastDate: _last);
    if (error != null) return error;
    if (_isRange && index == 1) {
      final start = _dates[0];
      final end = _dates[1];
      if (start != null && end != null && end.isBefore(start)) {
        return 'تاريخ النهاية قبل تاريخ البداية';
      }
    }
    return null;
  }

  bool get _canConfirm {
    for (var i = 0; i < _dates.length; i++) {
      if (_dates[i] == null || _errorFor(i) != null) return false;
    }
    return true;
  }

  void _onTyped(int index, String text) {
    final parsed = isDateInputComplete(text) ? parseDateInput(text) : null;
    final valid = parsed != null && !_outOfRange(parsed);
    setState(() {
      _dates[index] = valid ? parsed : null;
      if (valid) _calendarVersion++;
    });
  }

  void _onCalendarPicked(DateTime picked) {
    final day = _dayOnly(picked);
    setState(() {
      _dates[_active] = day;
      _controllers[_active].text = formatDateInput(day);
      if (_isRange && _active == 0) {
        final end = _dates[1];
        if (end != null && end.isBefore(day)) {
          _dates[1] = null;
          _controllers[1].clear();
        }
        if (_dates[1] == null && !_monthJump) {
          _active = 1;
          _calendarVersion++;
        }
      }
    });
  }

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(<DateTime>[for (final date in _dates) date!]);
  }

  // The end field only accepts days on or after the chosen start.
  bool _selectable(DateTime day) {
    if (!_isRange || _active != 1) return true;
    final start = _dates[0];
    return start == null || !day.isBefore(start);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final selected = _dates[_active];
    // The calendar opens on the active field's date when it can be picked.
    final calendarInitial = selected != null && _selectable(selected)
        ? selected
        : null;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width > 460 ? 400 : width - 40,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: const ['Tajawal'],
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              // One typed field per date; tapping one makes the calendar follow it.
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _dates.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _DateField(
                        label: widget.labels[i],
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        active: _active == i,
                        error: _errorFor(i),
                        onTap: () => _activate(i),
                        onChanged: (text) => _onTyped(i, text),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              // The calendar, in the app's colors. Its key changes when a typed date
              // moves it, so it re-centers on that month.
              Theme(
                data: theme.copyWith(
                  colorScheme: theme.colorScheme.copyWith(
                    primary: palette.accent,
                    onPrimary: palette.onAccent,
                    surface: palette.surface,
                    onSurface: palette.textPrimary,
                  ),
                ),
                child: CalendarDatePicker(
                  key: ValueKey('calendar-$_active-$_calendarVersion'),
                  initialDate: calendarInitial,
                  firstDate: _first,
                  lastDate: _last,
                  currentDate: _outOfRange(_dayOnly(DateTime.now()))
                      ? _last
                      : null,
                  initialCalendarMode:
                      widget.startWithYear &&
                          _calendarVersion == 0 &&
                          calendarInitial == null
                      ? DatePickerMode.year
                      : DatePickerMode.day,
                  selectableDayPredicate: _selectable,
                  onDisplayedMonthChanged: (_) {
                    _monthJump = true;
                    scheduleMicrotask(() => _monthJump = false);
                  },
                  onDateChanged: _onCalendarPicked,
                ),
              ),
              // Cancel, and confirm once every date is valid.
              const SizedBox(height: 8),
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
                        label: 'تأكيد',
                        primary: true,
                        enabled: _canConfirm,
                        onPressed: _confirm,
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

/// Label plus a DD/MM/YYYY field. The active one carries the accent outline.
class _DateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool active;
  final String? error;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  const _DateField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.active,
    required this.error,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final outline = BorderSide(
      color: active ? palette.accent : Colors.transparent,
      width: 1.4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 6, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: const ['Tajawal'],
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: active ? palette.accent : palette.textSecondary,
            ),
          ),
        ),
        TextField(
          controller: controller,
          focusNode: focusNode,
          onTap: onTap,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          inputFormatters: const [DateInputFormatter()],
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          cursorColor: palette.textPrimary,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontFamilyFallback: const ['Tajawal'],
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: palette.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: sheetFieldColor(context),
            hintText: dateInputHint,
            hintTextDirection: TextDirection.ltr,
            hintStyle: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: const ['Tajawal'],
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: palette.textSecondary.withValues(alpha: 0.6),
            ),
            errorText: error,
            errorMaxLines: 2,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: outline,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: outline,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: outline,
            ),
          ),
        ),
      ],
    );
  }
}
