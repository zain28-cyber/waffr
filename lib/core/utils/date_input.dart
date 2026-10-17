// Typed DD/MM/YYYY dates: separators are inserted while the user types digits,
// so the number pad is enough. Parsing rejects dates that do not exist.

import 'package:flutter/services.dart';
import 'package:waffr/core/utils/money.dart';

/// Shape shown as the field hint and in the picker help text.
const String dateInputHint = 'DD/MM/YYYY';

const String _separator = '/';
const int _maxDigits = 8;

final RegExp _nonDigits = RegExp(r'[^0-9]');
final RegExp _slashed = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');

/// Same text the app uses for dates everywhere (Western digits).
String formatDateInput(DateTime date) => formatDate(date);

/// Digits only in, DD/MM/YYYY out. A first day digit above 3 or a first month
/// digit above 1 is padded with a zero, so "4" becomes "04/". Deleting a
/// separator also deletes the digit before it.
class DateInputFormatter extends TextInputFormatter {
  /// A formatter for DD/MM/YYYY fields.
  const DateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = _digitsOf(newValue.text);
    final deleting = newValue.text.length < oldValue.text.length;
    if (deleting && digits.isNotEmpty && digits == _digitsOf(oldValue.text)) {
      digits = digits.substring(0, digits.length - 1);
    }

    final normalized = deleting ? digits : _padLeadingParts(digits);
    final clipped = normalized.length > _maxDigits
        ? normalized.substring(0, _maxDigits)
        : normalized;
    final text = _withSeparators(clipped, trailing: !deleting);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Western digits of [text], converting Arabic-Indic and Persian ones.
String _digitsOf(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final arabic = '٠١٢٣٤٥٦٧٨٩'.indexOf(char);
    final persian = '۰۱۲۳۴۵۶۷۸۹'.indexOf(char);
    if (arabic >= 0) {
      buffer.write(arabic);
    } else if (persian >= 0) {
      buffer.write(persian);
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString().replaceAll(_nonDigits, '');
}

/// Pads a day that can only be one digit (4-9) and a month above 1.
String _padLeadingParts(String digits) {
  var result = digits;
  if (result.isNotEmpty && int.parse(result[0]) > 3) {
    result = '0$result';
  }
  if (result.length > 2 && int.parse(result[2]) > 1) {
    result = '${result.substring(0, 2)}0${result.substring(2)}';
  }
  return result;
}

/// Inserts the slashes; [trailing] adds one after a finished part.
String _withSeparators(String digits, {required bool trailing}) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 2 || i == 4) buffer.write(_separator);
    buffer.write(digits[i]);
  }
  if (trailing && (digits.length == 2 || digits.length == 4)) {
    buffer.write(_separator);
  }
  return buffer.toString();
}

/// True once all eight digits are typed.
bool isDateInputComplete(String text) => _digitsOf(text).length == _maxDigits;

/// A real calendar date from DD/MM/YYYY (or eight bare digits), else null.
DateTime? parseDateInput(String? text) {
  if (text == null) return null;
  final trimmed = text.trim();
  int? day;
  int? month;
  int? year;

  final match = _slashed.firstMatch(trimmed);
  if (match != null) {
    day = int.tryParse(match.group(1)!);
    month = int.tryParse(match.group(2)!);
    year = int.tryParse(match.group(3)!);
  } else {
    final digits = _digitsOf(trimmed);
    if (digits.length != _maxDigits || digits.length != trimmed.length) {
      return null;
    }
    day = int.parse(digits.substring(0, 2));
    month = int.parse(digits.substring(2, 4));
    year = int.parse(digits.substring(4));
  }

  if (day == null || month == null || year == null) return null;
  if (year < 1900 || year > 2100) return null;
  if (month < 1 || month > 12) return null;
  final lastDay = DateTime(year, month + 1, 0).day;
  if (day < 1 || day > lastDay) return null;
  return DateTime(year, month, day);
}

/// Arabic error for a typed date, or null when it is fine or still incomplete.
String? dateInputError(
  String text, {
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  if (!isDateInputComplete(text)) return null;
  final date = parseDateInput(text);
  if (date == null) return 'هذا التاريخ غير موجود';
  final first = DateTime(firstDate.year, firstDate.month, firstDate.day);
  final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
  if (date.isBefore(first) || date.isAfter(last)) {
    return 'اختر تاريخاً بين ${formatDate(first)} و${formatDate(last)}';
  }
  return null;
}
