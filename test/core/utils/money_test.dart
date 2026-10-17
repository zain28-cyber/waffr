// Money and date formatting: whole amounts with separators, DD/MM/YYYY and
// HH:mm in the device zone, and currency labels.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/utils/money.dart';

import '../../helpers/store_harness.dart';

void main() {
  test('formatMoney rounds and groups thousands', () {
    expect(formatMoney(0), '0');
    expect(formatMoney(1500), '1,500');
    expect(formatMoney(1234567.4), '1,234,567');
    expect(formatMoney(2.5), '3');
    expect(formatMoney(-1500), '-1,500');
  });

  test('dates and times use Latin digits and two-digit parts', () {
    expect(formatDate(DateTime(2026, 3, 4, 5, 6)), '04/03/2026');
    expect(formatTime(DateTime(2026, 3, 4, 5, 6)), '05:06');
    final utc = DateTime.utc(2026, 1, 1, 12);
    expect(formatDate(utc), formatDate(utc.toLocal()));
  });

  test('currency labels', () async {
    await setUpStores();
    expect(sypCurrencyLabel, 'ل.س');
    expect(currencyLabel, 'ل.س');
    expect(currencyLabelFor('usd'), r'$');
    expect(currencyLabelFor(null), 'ل.س');
  });
}
