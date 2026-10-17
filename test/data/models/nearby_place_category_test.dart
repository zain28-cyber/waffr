// Nearby place chips for the online tab (the Maps launcher itself is a
// platform call and is not exercised here).

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/nearby_place_category.dart';

void main() {
  test('nearby place chips have labels and queries', () {
    expect(nearbyPlaceCategories, hasLength(4));
    for (final chip in nearbyPlaceCategories) {
      expect(chip.label, isNotEmpty);
      expect(chip.mapsQuery, isNotEmpty);
    }
  });
}
