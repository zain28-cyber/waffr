// Generates every reminder and insight phrasing over many random ledgers
// and checks each text: no placeholders or stray spacing, numbers that
// agree with their nouns, category names with the article, balanced
// direction marks, and (for reminders) no "open the app" wording.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/insights/smart/insight_engine.dart';
import 'package:waffr/core/insights/smart/reminder_digest.dart';
import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/data/models/transaction.dart';

const _categories = [
  'طعام',
  'مواصلات',
  'تسوق',
  'فواتير',
  'صحة',
  'ترفيه',
  'تعليم',
  'أخرى',
];
const _nudges = ['افتح', 'عُد ', 'ادخل', 'سجّل', 'التطبيق', 'اضغط'];

final _countNoun = RegExp(
  r'(\d[\d,]*) (أيام|يوماً|يوم|أشهر|شهراً|شهر|دفعات|دفعة|مصاريف|مصروفاً|مصروف|مرات|مرة|أهداف|هدفاً|عناصر|عنصراً)(?=[\s.،:!؟)]|$)',
);
final _bareCategory = RegExp(
  '(?:على|في|إلى|ب|ل) (?:${_categories.where((c) => c != 'أخرى').join('|')})(?=[\\s.،:!؟]|\$)',
);

const _plural = {'أيام', 'أشهر', 'دفعات', 'مصاريف', 'مرات', 'أهداف', 'عناصر'};
const _accusative = {'يوماً', 'شهراً', 'مصروفاً', 'هدفاً', 'عنصراً'};
const _genitive = {'يوم', 'شهر', 'مصروف'};
// Feminine nouns whose accusative and genitive singular look the same.
const _same = {'دفعة', 'مرة'};

List<String> _problems(String text, {bool reminder = false}) {
  final issues = <String>[];
  if (text.trim().isEmpty) issues.add('empty');
  if (text != text.trim()) issues.add('edge spaces');
  if (text.contains('  ')) issues.add('double space');
  for (final bad in [
    'null',
    r'$',
    '{',
    '}',
    'NaN',
    'Infinity',
    '..',
    '،،',
    ' ،',
    ' .',
  ]) {
    if (text.contains(bad)) issues.add('contains "$bad"');
  }
  if ('\u2066'.allMatches(text).length != '\u2069'.allMatches(text).length) {
    issues.add('unbalanced isolates');
  }
  if (_bareCategory.hasMatch(text)) issues.add('category without article');
  if (reminder) {
    for (final word in _nudges) {
      if (text.contains(word)) issues.add('nudge "$word"');
    }
  }
  for (final match in _countNoun.allMatches(text)) {
    final n = int.parse(match.group(1)!.replaceAll(',', ''));
    final noun = match.group(2)!;
    final rest = n >= 100 ? n % 100 : n;
    final ok =
        n >= 3 &&
        switch (noun) {
          _ when _plural.contains(noun) => rest >= 3 && rest <= 10,
          _ when _accusative.contains(noun) =>
            rest >= 11 || (n < 100 && n >= 11),
          _ when _genitive.contains(noun) => n >= 100 && rest <= 2,
          _ when _same.contains(noun) => rest >= 11 || (n >= 100 && rest <= 2),
          _ => false,
        };
    if (!ok) issues.add('"${match.group(0)}" disagrees');
  }
  return issues;
}

SmartFacts _randomFacts(math.Random r, DateTime now) {
  var id = 0;
  final expenses = <WaffrTransaction>[];
  final spread = 1 + r.nextInt(4);
  for (var back = 0; back < 70; back++) {
    if (r.nextDouble() < 0.25) continue;
    final day = now.subtract(Duration(days: back, hours: r.nextInt(14)));
    for (var k = 0; k < spread; k++) {
      expenses.add(
        WaffrTransaction(
          id: 'e${id++}',
          type: TransactionType.expense,
          amount: (5 + r.nextInt(400)) * (r.nextBool() ? 1000.0 : 1.0),
          dateTime: day,
          category: _categories[r.nextInt(_categories.length)],
          paymentMethod: r.nextBool() ? 'بطاقة' : 'نقداً',
          note: r.nextDouble() < 0.2 ? 'غداء' : null,
        ),
      );
    }
  }
  final transfers = <WaffrTransaction>[
    for (var i = 0; i < r.nextInt(6); i++)
      WaffrTransaction(
        id: 't${id++}',
        type: r.nextDouble() < 0.3
            ? TransactionType.savingsOut
            : TransactionType.savingsIn,
        amount: 1000.0 + r.nextInt(90000),
        dateTime: now.subtract(Duration(days: r.nextInt(80))),
        goalId: r.nextBool() ? 'g0' : null,
        transferKind: r.nextBool()
            ? SavingsTransferKind.periodLeftover
            : SavingsTransferKind.manual,
      ),
  ];
  final income = r.nextDouble() < 0.8 ? 100000.0 + r.nextInt(3000000) : null;
  return SmartFacts(
    now: now,
    currencySymbol: 'ل.س',
    expenses: expenses,
    incomes: [
      if (income != null)
        WaffrTransaction(
          id: 'i${id++}',
          type: TransactionType.income,
          amount: income,
          dateTime: DateTime(now.year, now.month),
        ),
    ],
    savingsTransfers: transfers,
    balance: r.nextDouble() < 0.1 ? 0 : 1000.0 + r.nextInt(2000000),
    monthlyIncome: income,
    incomeFrequency: r.nextBool()
        ? RecurringFrequency.monthly
        : RecurringFrequency.weekly,
    hasRecurringIncome: income != null,
    savingsBalance: r.nextInt(5000000).toDouble(),
    goals: [
      for (var g = 0; g < r.nextInt(4); g++)
        GoalFact(
          id: 'g$g',
          name: ['سفر', 'لابتوب', 'صندوق الطوارئ', 'Car'][g % 4],
          target: 100000.0 + r.nextInt(5000000),
          saved: r.nextInt(5000000).toDouble(),
          createdAt: now.subtract(Duration(days: r.nextInt(200))),
          plannedMonths: [0.25, 1.0, 3.0, 6.0, 12.0][r.nextInt(5)],
        ),
    ],
    completedGoals: r.nextInt(14),
    obligations: [
      for (var o = 0; o < r.nextInt(14); o++)
        ObligationFact(
          name: ['إيجار', 'إنترنت', 'اشتراك نادي', 'فواتير'][o % 4],
          amount: 1000.0 + r.nextInt(500000),
          monthlyEquivalent: 1000.0 + r.nextInt(500000),
          nextDueAt: now.add(Duration(days: r.nextInt(9))),
        ),
    ],
    pendingShopping: r.nextInt(15),
    streakCount: 1 + r.nextInt(130),
    usageStartedAt: now.subtract(Duration(days: r.nextInt(400))),
  );
}

void main() {
  final scenarios = math.Random(2026);
  final dates = [
    DateTime(2026, 10, 3, 9),
    DateTime(2026, 10, 20, 12),
    DateTime(2026, 10, 30, 22),
    DateTime(2026, 2, 27, 8),
  ];

  test('every reminder text is clean, factual and grammatical', () {
    final failures = <String>{};
    var checked = 0;
    final kinds = <String>{};
    for (var s = 0; s < 80; s++) {
      final now = dates[s % dates.length];
      final facts = _randomFacts(scenarios, now);
      for (var seed = 0; seed < 12; seed++) {
        final digest = ReminderDigest(facts, seed: seed);
        final texts = [
          ...digest.candidates(now.add(const Duration(days: 2))),
          ...digest.candidates(now.add(const Duration(days: 5))),
          ?digest.weekly(),
          ReminderDigest.streakText(2 + (s * 7 + seed) % 120, seed: seed),
        ];
        for (final text in texts) {
          kinds.add(text.kind);
          checked++;
          for (final part in [text.title, text.body]) {
            for (final issue in _problems(part, reminder: true)) {
              failures.add('${text.kind}: $issue → $part');
            }
          }
          if (text.title.endsWith('.')) {
            failures.add('title ends with "." → ${text.title}');
          }
          if (!text.body.endsWith('.')) {
            failures.add('body without "." → ${text.body}');
          }
          if (text.title.length > 70) {
            failures.add('long title → ${text.title}');
          }
          if (text.body.length > 140) failures.add('long body → ${text.body}');
        }
      }
    }
    expect(failures, isEmpty, reason: failures.take(30).join('\n'));
    expect(checked, greaterThan(3000));
    expect(
      kinds,
      containsAll([
        'obligation',
        'payments',
        'short-balance',
        'balance',
        'category',
        'goal',
        'top-share',
        'no-spend',
        'savings',
        'month',
        'weekly',
        'streak',
      ]),
    );
  });

  test('every insight text is clean and grammatical', () {
    final failures = <String>{};
    for (var s = 0; s < 60; s++) {
      final now = dates[s % dates.length];
      final facts = _randomFacts(scenarios, now);
      for (var seed = 0; seed < 6; seed++) {
        for (final scope in InsightScope.values) {
          final report = InsightEngine(facts, seed: seed).analyze(scope);
          for (final part in [
            report.headline,
            report.summary,
            for (final item in report.insights) ...[
              item.title,
              item.body,
              ?item.detail,
            ],
          ]) {
            if (part.isEmpty) continue;
            for (final line in part.split('\n')) {
              for (final issue in _problems(line)) {
                failures.add('${scope.name}: $issue → $line');
              }
            }
          }
        }
      }
    }
    expect(failures, isEmpty, reason: failures.take(30).join('\n'));
  });

  test('the checker itself catches broken grammar', () {
    expect(_problems('بعد 11 أيام.'), isNotEmpty);
    expect(_problems('بعد 4 يوماً.'), isNotEmpty);
    expect(_problems('بعد 2 أيام.'), isNotEmpty);
    expect(_problems('صرفت على ترفيه.'), isNotEmpty);
    expect(_problems('افتح التطبيق.', reminder: true), isNotEmpty);
    expect(_problems('بعد 12 يوماً.'), isEmpty);
    expect(_problems('بعد 101 يوم.'), isEmpty);
    expect(_problems('صرفت على الترفيه.'), isEmpty);
  });
}
