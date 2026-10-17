// SpendingImprovement.calculate: a drop is a positive percentage, a rise a
// negative one, and nothing to compare gives a neutral dash.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/insights/spending_improvement.dart';

void main() {
  SpendingImprovement calc(double current, double previous) =>
      SpendingImprovement.calculate(
        currentTotal: current,
        previousTotal: previous,
      );

  test('less spending is an improvement', () {
    final result = calc(75, 100);
    expect(result.kind, SpendingChange.positive);
    expect(result.text, '+25.0%');
    expect(result.detail, 'المصروف انخفض مقارنة بالفترة السابقة');
    expect(result.hasPercentage, isTrue);
  });

  test('more spending is shown with a minus sign', () {
    final result = calc(133.3, 100);
    expect(result.kind, SpendingChange.negative);
    expect(result.text, '−33.3%');
    expect(result.hasPercentage, isTrue);
  });

  test('no change', () {
    final result = calc(100, 100);
    expect(result.kind, SpendingChange.neutral);
    expect(result.text, '0%');
    expect(result.detail, 'لا تغيير في المصروف');
  });

  test('nothing in the previous period', () {
    final empty = calc(0, 0);
    expect(empty.kind, SpendingChange.neutral);
    expect(empty.text, '—');
    expect(empty.detail, 'لا توجد بيانات للمقارنة');
    expect(empty.hasPercentage, isFalse);

    final fresh = calc(50, 0);
    expect(fresh.detail, 'لا توجد مصروفات في الفترة السابقة');
    expect(fresh.hasPercentage, isFalse);
  });

  test('spending dropped to zero is a full improvement', () {
    expect(calc(0, 80).text, '+100.0%');
  });
}
