// Typed DD/MM/YYYY dates: the input formatter, parsing real dates, range
// errors, and Arabic-Indic digit conversion.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/l10n/waffr_material_localizations.dart';
import 'package:waffr/core/utils/date_input.dart';

void main() {
  const formatter = DateInputFormatter();

  // Types [keys] one character at a time, as the number pad would.
  String type(String keys, {String start = ''}) {
    var value = TextEditingValue(
      text: start,
      selection: TextSelection.collapsed(offset: start.length),
    );
    for (final key in keys.split('')) {
      final next = '${value.text}$key';
      value = formatter.formatEditUpdate(
        value,
        TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        ),
      );
    }
    return value.text;
  }

  String backspace(String text) {
    final next = text.substring(0, text.length - 1);
    return formatter
        .formatEditUpdate(
          TextEditingValue(text: text),
          TextEditingValue(text: next),
        )
        .text;
  }

  test('inserts the separators while digits are typed', () {
    expect(type('1'), '1');
    expect(type('12'), '12/');
    expect(type('1205'), '12/05/');
    expect(type('12052026'), '12/05/2026');
    expect(type('120520261'), '12/05/2026');
  });

  test('pads a day or month that cannot take a second digit', () {
    expect(type('4'), '04/');
    expect(type('123'), '12/03/');
    expect(type('47'), '04/07/');
  });

  test('deleting a separator also removes the digit before it', () {
    expect(backspace('12/'), '1');
    expect(backspace('12/05/'), '12/0');
    expect(backspace('12/05/2'), '12/05');
  });

  test('accepts Arabic-Indic digits and ignores other characters', () {
    expect(type('١٢٠٥٢٠٢٦'), '12/05/2026');
    expect(type('1a2'), '12/');
  });

  test('parses only real dates', () {
    expect(parseDateInput('29/02/2024'), DateTime(2024, 2, 29));
    expect(parseDateInput('29/02/2023'), isNull);
    expect(parseDateInput('31/04/2026'), isNull);
    expect(parseDateInput('00/01/2026'), isNull);
    expect(parseDateInput('12/13/2026'), isNull);
    expect(parseDateInput('12052026'), DateTime(2026, 5, 12));
    expect(parseDateInput('12/05/20'), isNull);
  });

  test('explains invalid or out-of-range dates once complete', () {
    final first = DateTime(2000);
    final last = DateTime(2026, 10, 8);
    expect(dateInputError('12/0', firstDate: first, lastDate: last), isNull);
    expect(
      dateInputError('31/02/2020', firstDate: first, lastDate: last),
      'هذا التاريخ غير موجود',
    );
    expect(
      dateInputError('01/01/1999', firstDate: first, lastDate: last),
      'اختر تاريخاً بين 01/01/2000 و08/10/2026',
    );
    expect(
      dateInputError('08/10/2026', firstDate: first, lastDate: last),
      isNull,
    );
  });

  test('converts Arabic-Indic digits for the date pickers', () {
    expect(westernDigits('٢٠٢٦/١٠/٠٨'), '2026/10/08');
    expect(westernDigits('۱۲ أكتوبر'), '12 أكتوبر');
  });

  test('completeness and the shared date format', () {
    expect(isDateInputComplete('12/05/2026'), isTrue);
    expect(isDateInputComplete('12/05/202'), isFalse);
    expect(formatDateInput(DateTime(2026, 5, 12)), '12/05/2026');
    expect(dateInputHint, 'DD/MM/YYYY');
  });

  test('parsing edge cases', () {
    expect(parseDateInput(null), isNull);
    expect(parseDateInput(' 1/2/2026 '), DateTime(2026, 2, 1));
    expect(parseDateInput('01/01/1899'), isNull);
    expect(parseDateInput('01/01/2101'), isNull);
    expect(parseDateInput('12-05-2026'), isNull);
    expect(parseDateInput('١٢٠٥٢٠٢٦'), DateTime(2026, 5, 12));
  });
}
