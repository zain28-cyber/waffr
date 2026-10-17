// Currency catalog: normalization, lookups for known and unknown codes, and
// the symbol helper.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/currency.dart';

void main() {
  test('SYP is the default and the first catalog entry', () {
    expect(defaultCurrencyCode, 'SYP');
    expect(Currencies.catalog.first.code, 'SYP');
    expect(Currencies.syp.symbol, 'ل.س');
  });

  test('catalog codes are unique upper-case ISO codes', () {
    final codes = Currencies.catalog.map((item) => item.code).toList();
    expect(codes.toSet(), hasLength(codes.length));
    for (final code in codes) {
      expect(code, matches(RegExp(r'^[A-Z]{3}$')));
    }
  });

  test('normalize trims, upper-cases and defaults to SYP', () {
    expect(Currencies.normalize(' usd '), 'USD');
    expect(Currencies.normalize(null), 'SYP');
    expect(Currencies.normalize(''), 'SYP');
    expect(Currencies.normalize('   '), 'SYP');
    expect(Currencies.normalize('xyz'), 'XYZ');
  });

  test('of finds catalog rows regardless of case', () {
    final usd = Currencies.of('usd');
    expect(usd.code, 'USD');
    expect(usd.arabicName, 'دولار أمريكي');
    expect(usd.symbol, r'$');
  });

  test('unknown codes get a placeholder named after the code', () {
    final unknown = Currencies.of('abc');
    expect(unknown.code, 'ABC');
    expect(unknown.arabicName, 'ABC');
    expect(unknown.symbol, 'ABC');
    expect(Currencies.isKnown('abc'), isFalse);
    expect(Currencies.isKnown('eur'), isTrue);
  });

  test('symbolOf falls back to SYP for null', () {
    expect(Currencies.symbolOf(null), 'ل.س');
    expect(Currencies.symbolOf('eur'), '€');
    expect(Currencies.symbolOf('JPY'), '¥');
  });
}
