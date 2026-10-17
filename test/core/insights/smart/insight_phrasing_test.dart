// InsightPhrasing: money/percent/day formatting, seeded picks, and say()
// never reusing an opener or closer within one report.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/insights/smart/insight_phrasing.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';

void main() {
  InsightPhrasing phrasing([int seed = 1]) =>
      InsightPhrasing('ل.س', math.Random(seed));

  test('formatting helpers', () {
    final p = phrasing();
    expect(p.money(1234.6), '1,235 ل.س');
    expect(p.percent(0.255), '\u206626%\u2069');
    expect(p.percent(-0.1), '\u206610%\u2069', reason: 'the sign is dropped');
    expect(p.days(0), 'أقل من يوم');
    expect(p.days(1), 'يوم واحد');
    expect(p.days(12), '12 يوماً');
  });

  test('the same seed picks the same words', () {
    final options = List.generate(20, (i) => 'o$i');
    final a = phrasing(7);
    final b = phrasing(7);
    for (var i = 0; i < 10; i++) {
      expect(a.pick(options), b.pick(options));
      expect(a.nextInt(100), b.nextInt(100));
    }
    final list = [1, 2, 3, 4, 5];
    final other = [1, 2, 3, 4, 5];
    phrasing(3).shuffle(list);
    phrasing(3).shuffle(other);
    expect(list, other);
  });

  test('say keeps the core and never repeats an opener or closer', () {
    final p = phrasing(11);
    final extras = <String>[];
    for (var i = 0; i < 30; i++) {
      final text = p.say(InsightTone.positive, ['جوهر النص.']);
      expect(text, contains('جوهر النص.'));
      final rest = text.replaceFirst('جوهر النص.', '|').split('|');
      extras.addAll(rest.map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    expect(extras.toSet().length, extras.length);
  });

  test('long cores get no closer', () {
    final long = 'ا' * 120;
    for (var seed = 0; seed < 20; seed++) {
      final text = phrasing(seed).say(InsightTone.warning, [long]);
      expect(text.endsWith(long), isTrue);
    }
  });
}
