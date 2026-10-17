// ExchangeRate: a row without a live quote shows the unavailable minus.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/exchange_rate.dart';

void main() {
  test('exchange rates default to no quote', () {
    const rate = ExchangeRate(code: 'USD', chipLabel: r'$', pairLabel: 'دولار');
    expect(rate.buy, isNull);
    expect(rate.sell, isNull);
    expect(rate.updatedAt, isNull);
    expect(ExchangeRate.unavailable, '−');
  });
}
