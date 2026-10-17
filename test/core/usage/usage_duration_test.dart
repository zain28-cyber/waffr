// usageDurationText: compact Arabic durations with number agreement, using
// 30-day months and 12-month years.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/usage/usage_duration.dart';

void main() {
  final start = DateTime(2025, 1, 1, 22);
  String after(int days) => usageDurationText(
    start,
    DateTime(2025, 1, 1).add(Duration(days: days, hours: 3)),
  );

  test('days', () {
    expect(after(0), 'اليوم');
    expect(after(1), 'يوم');
    expect(after(2), 'يومان');
    expect(after(10), '10 أيام');
    expect(after(11), '11 يوماً');
    expect(after(29), '29 يوماً');
  });

  test('months and days', () {
    expect(after(30), 'شهر');
    expect(after(61), 'شهران ويوم');
    expect(after(95), '3 أشهر و5 أيام');
    expect(after(330 + 12), '11 شهراً و12 يوماً');
  });

  test('years and months', () {
    expect(after(360), 'سنة');
    expect(after(360 * 2 + 60), 'سنتان وشهران');
    expect(after(360 * 3), '3 سنوات');
    expect(after(360 * 11 + 30), '11 سنة وشهر');
  });

  test('a start in the future reads as today', () {
    expect(usageDurationText(DateTime(2030), DateTime(2026)), 'اليوم');
  });
}
