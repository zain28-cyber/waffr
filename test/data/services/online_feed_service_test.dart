// OnlineFeedService rate rows (placeholders for every non-SYP currency plus
// gold). The news fetch is an HTTP call and is not exercised here.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/currency.dart';
import 'package:waffr/data/services/online_feed_service.dart';

void main() {
  test('one placeholder row per non-SYP currency, then gold', () {
    final codes = OnlineFeedService.rates.map((rate) => rate.code).toList();
    expect(codes, isNot(contains('SYP')));
    expect(codes.length, Currencies.catalog.length);
    expect(codes.last, 'GOLD21');
    expect(OnlineFeedService.rates.every((rate) => rate.buy == null), isTrue);
  });

  test('rateFor finds a row and throws for unknown codes', () {
    final usd = OnlineFeedService.rateFor('USD');
    expect(usd.chipLabel, r'$');
    expect(usd.pairLabel, 'دولار أمريكي');
    expect(OnlineFeedService.rateFor('GOLD21').pairLabel, 'ذهب عيار 21');
    expect(() => OnlineFeedService.rateFor('SYP'), throwsStateError);
  });
}
