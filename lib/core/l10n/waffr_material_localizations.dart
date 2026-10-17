// Arabic Material strings with Western digits (0-9) for pickers and dates.
//
// Flutter's Arabic localization formats calendar days, years and headers with
// Arabic-Indic digits. The rest of the app shows money and dates with 0-9, so
// the date pickers follow the same rule. Registered before
// GlobalMaterialLocalizations.delegate in main.dart, so it wins for 'ar'.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:waffr/core/utils/date_input.dart';

const String _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
const String _easternArabicIndicDigits = '۰۱۲۳۴۵۶۷۸۹';

/// Replaces Arabic-Indic and Persian digits with 0-9. Other text is kept.
String westernDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    var index = _arabicIndicDigits.indexOf(char);
    if (index < 0) index = _easternArabicIndicDigits.indexOf(char);
    buffer.write(index < 0 ? char : '$index');
  }
  return buffer.toString();
}

// intl's Arabic month names → the Levantine names used across the app
// (CalendarPeriod.monthNames), so the pickers match reports and lists.
const Map<String, String> _levantineMonths = {
  'يناير': 'كانون الثاني',
  'فبراير': 'شباط',
  'مارس': 'آذار',
  'أبريل': 'نيسان',
  'مايو': 'أيار',
  'يونيو': 'حزيران',
  'يوليو': 'تموز',
  'أغسطس': 'آب',
  'سبتمبر': 'أيلول',
  'أكتوبر': 'تشرين الأول',
  'نوفمبر': 'تشرين الثاني',
  'ديسمبر': 'كانون الأول',
};

// Western digits and Levantine month names in a formatted date.
String _appDate(String input) {
  var text = westernDigits(input);
  _levantineMonths.forEach((from, to) => text = text.replaceAll(from, to));
  return text;
}

/// Arabic Material strings whose dates use 0-9 and Levantine month names.
class WaffrMaterialLocalizations extends MaterialLocalizationAr {
  const WaffrMaterialLocalizations._({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  /// Register before `GlobalMaterialLocalizations.delegate` in the app.
  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _WaffrMaterialLocalizationsDelegate();

  // The global delegate answers synchronously, so `then` keeps this
  // synchronous too and the first frame is not held back.
  static Future<MaterialLocalizations> _load(Locale locale) {
    // Loads intl's Arabic date symbols the same way Flutter does.
    return GlobalMaterialLocalizations.delegate
        .load(locale)
        .then((_) => _build());
  }

  // The Arabic formats with native digits switched off.
  static MaterialLocalizations _build() {
    const name = 'ar';
    intl.DateFormat.useNativeDigitsByDefaultFor(name, false);

    intl.DateFormat latin(intl.DateFormat format) {
      format.useNativeDigits = false;
      return format;
    }

    return WaffrMaterialLocalizations._(
      fullYearFormat: latin(intl.DateFormat.y(name)),
      compactDateFormat: latin(intl.DateFormat.yMd(name)),
      shortDateFormat: latin(intl.DateFormat.yMMMd(name)),
      mediumDateFormat: latin(intl.DateFormat.MMMEd(name)),
      longDateFormat: latin(intl.DateFormat.yMMMMEEEEd(name)),
      yearMonthFormat: latin(intl.DateFormat.yMMMM(name)),
      shortMonthDayFormat: latin(intl.DateFormat.MMMd(name)),
      decimalFormat: intl.NumberFormat.decimalPattern('en'),
      twoDigitZeroPaddedFormat: intl.NumberFormat('00', 'en'),
    );
  }

  @override
  String formatYear(DateTime date) => _appDate(super.formatYear(date));

  @override
  String formatMonthYear(DateTime date) =>
      _appDate(super.formatMonthYear(date));

  @override
  String formatMediumDate(DateTime date) =>
      _appDate(super.formatMediumDate(date));

  @override
  String formatFullDate(DateTime date) => _appDate(super.formatFullDate(date));

  @override
  String formatShortDate(DateTime date) =>
      _appDate(super.formatShortDate(date));

  @override
  String formatShortMonthDay(DateTime date) =>
      _appDate(super.formatShortMonthDay(date));

  @override
  String formatDecimal(int number) =>
      westernDigits(super.formatDecimal(number));

  // Same DD/MM/YYYY shape the app shows everywhere else.
  @override
  String formatCompactDate(DateTime date) => formatDateInput(date);

  @override
  DateTime? parseCompactDate(String? inputString) {
    if (inputString == null) return null;
    return parseDateInput(westernDigits(inputString));
  }

  @override
  String get dateHelpText => dateInputHint;
}

/// Loads [WaffrMaterialLocalizations] for Arabic locales only.
class _WaffrMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _WaffrMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ar';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      WaffrMaterialLocalizations._load(locale);

  @override
  bool shouldReload(_WaffrMaterialLocalizationsDelegate old) => false;
}
