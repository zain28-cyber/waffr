// Country catalog and its search: Arab countries first, letter folding,
// ISO codes and calling-code prefixes.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/country.dart';

void main() {
  List<String> isos(String query) =>
      Countries.search(query).map((item) => item.iso).toList();

  test('Syria leads the list and Arab countries come first', () {
    expect(Countries.all.first.iso, 'SY');
    expect(Countries.all.take(Countries.arab.length), Countries.arab);
    expect(
      Countries.all.length,
      Countries.arab.length + Countries.others.length,
    );
  });

  test('ISO codes are unique', () {
    final codes = Countries.all.map((item) => item.iso).toList();
    expect(codes.toSet(), hasLength(codes.length));
  });

  test('dial label adds the plus', () {
    expect(Countries.all.first.dialLabel, '+963');
  });

  test('an empty query returns everything', () {
    expect(Countries.search(''), Countries.all);
    expect(Countries.search('   '), Countries.all);
  });

  test('hamza, ta marbuta and alef maqsura variants are folded', () {
    expect(isos('الاردن'), ['JO']);
    expect(isos('الإمارات'), ['AE']);
    expect(isos('الامارات'), ['AE']);
    expect(isos('سنغافوره'), ['SG']);
    expect(isos('عمان'), ['OM'], reason: 'the damma in عُمان is dropped');
  });

  test('ISO codes match whole and case-insensitively', () {
    expect(isos('sy'), ['SY']);
    expect(isos('DE'), ['DE']);
    expect(isos('s'), isEmpty, reason: 'one letter is not an ISO code');
  });

  test('calling codes match by prefix, with or without the plus', () {
    expect(isos('+963'), ['SY']);
    expect(isos('963'), ['SY']);
    expect(isos('+1'), containsAll(['US', 'CA', 'JM', 'DO']));
    expect(isos('97'), containsAll(['PS', 'AE', 'QA', 'BH', 'NP', 'MN']));
    expect(isos('97'), isNot(contains('OM')), reason: 'Oman is +968');
  });

  test('partial Arabic names match anywhere in the name', () {
    expect(isos('سود'), containsAll(['SD', 'SS']));
    expect(isos('غير موجود'), isEmpty);
  });
}
