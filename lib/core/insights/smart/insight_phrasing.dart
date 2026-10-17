// Wording helpers shared by every insight rule: random phrasing choices,
// money and percent formatting, and the optional openers and closers that
// make repeated runs read like newly written text.

import 'dart:math' as math;

import 'package:waffr/core/insights/smart/arabic_text.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/core/utils/money.dart';

/// Picks and formats the words of one analysis run.
///
/// One instance is shared by all rule groups of a run, in a fixed order, so
/// a given seed always produces the same report.
class InsightPhrasing {
  /// Phrasing for amounts in [currencySymbol], driven by [random].
  InsightPhrasing(this.currencySymbol, this._random);

  /// Symbol appended to every amount.
  final String currencySymbol;

  final math.Random _random;

  // Openers and closers already used in this report.
  final Set<String> _usedPhrases = {};

  /// A random integer in [0, max), from the run's random source.
  int nextInt(int max) => _random.nextInt(max);

  /// Shuffles [items] in place with the run's random source.
  void shuffle(List<Object?> items) => items.shuffle(_random);

  /// One of [options], chosen at random.
  T pick<T>(List<T> options) => options[_random.nextInt(options.length)];

  /// An amount with the currency symbol ("1,500 ل.س").
  String money(double value) => '${formatMoney(value)} $currencySymbol';

  /// A ratio as a whole percent, isolated left-to-right so "20%" never
  /// flips inside Arabic text.
  String percent(double ratio) => '\u2066${(ratio * 100).abs().round()}%\u2069';

  /// A day count in words; below one it reads "less than a day".
  String days(int n) => n < 1 ? 'أقل من يوم' : Ar.days.of(n);

  static const List<String> _openers = [
    'بحسب أرقامك،',
    'بعد مراجعة بياناتك،',
    'من خلال ما سجّلته،',
    'بالنظر إلى مصاريفك الأخيرة،',
    'وفق ما لاحظته،',
  ];

  static const Map<InsightTone, List<String>> _closers = {
    InsightTone.warning: [
      'تعديل بسيط الآن يوفّر عليك الكثير لاحقاً.',
      'يستحق هذا البند مراقبة أدق في الأيام القادمة.',
      'الانتباه المبكر يجعل التصحيح أسهل.',
      'ضع لهذا البند حدّاً واضحاً والتزم به.',
    ],
    InsightTone.positive: [
      'استمرّ على هذا النهج.',
      'تقدّم يستحق الإشادة.',
      'عادة ممتازة، حافظ عليها.',
      'خطوة في الاتجاه الصحيح.',
    ],
    InsightTone.tip: [
      'جرّبها هذا الأسبوع ولاحظ الفرق.',
      'خطوة صغيرة لكن أثرها كبير.',
      'يمكنك البدء بها اليوم.',
    ],
    InsightTone.info: [
      'معلومة تفيدك في التخطيط للشهر القادم.',
      'ضعها في حسابك عند التخطيط.',
    ],
  };

  /// A body built from one of [cores], sometimes with an opener and a
  /// closing remark in the given [tone]. Openers and closers are used at
  /// most once per report, so two cards never end with the same remark.
  String say(InsightTone tone, List<String> cores) {
    final core = pick(cores);
    final parts = <String>[];

    final opener = _fresh(_openers);
    if (opener != null && _random.nextDouble() < 0.35) {
      parts.add(opener);
      _usedPhrases.add(opener);
    }
    parts.add(core);

    // Long sentences stand alone; a closer would make them run on.
    final closer = _fresh(_closers[tone]!);
    if (closer != null && core.length < 110 && _random.nextDouble() < 0.5) {
      parts.add(closer);
      _usedPhrases.add(closer);
    }
    return parts.join(' ');
  }

  // A phrase from [options] not used yet in this report, or null.
  String? _fresh(List<String> options) {
    final unused = [
      for (final item in options)
        if (!_usedPhrases.contains(item)) item,
    ];
    return unused.isEmpty ? null : pick(unused);
  }
}
