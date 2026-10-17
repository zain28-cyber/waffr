// Short, factual notification texts built from SmartFacts. Each one states
// something true and useful (a bill coming up, how far the balance goes,
// a category that grew, goal progress, the week's total) and never asks
// the user to open the app; the fact itself is the reason to come back.
//
// Texts are written when the app is open and shown days later. Nothing
// changes in the ledger meanwhile (it only changes inside the app), so the
// amounts stay true; dates are counted from the time the text will show.
// Every kind has several phrasings; the seed picks one.

import 'dart:math' as math;

import 'package:waffr/core/insights/smart/arabic_text.dart';
import 'package:waffr/core/insights/smart/insight_phrasing.dart';
import 'package:waffr/core/insights/smart/report_insights.dart';
import 'package:waffr/core/insights/smart/smart_facts.dart';

/// One notification text: which fact it states ([kind]), and its words.
typedef ReminderText = ({String kind, String title, String body});

/// Writes the factual reminder texts for one set of [SmartFacts].
class ReminderDigest {
  /// The numbers the texts state.
  final SmartFacts facts;

  final InsightPhrasing _p;

  /// Texts over [facts]; a fixed [seed] fixes the phrasing (tests).
  ReminderDigest(this.facts, {int? seed})
    : _p = InsightPhrasing(facts.currencySymbol, math.Random(seed));

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  // Days from today to [at]'s day.
  int _offset(DateTime at) => _day(at).difference(facts.today).inDays;

  /// Facts worth a notification at [fireAt]. Time-sensitive ones (a bill,
  /// a balance that will not last) come first; the rest in varying order.
  List<ReminderText> candidates(DateTime fireAt) {
    final urgent = [?_obligation(fireAt), ?_shortBalance(fireAt)];
    final rest = [
      ?_paymentsAhead(fireAt),
      ?_balance(fireAt),
      ?_categoryChange(),
      ?_goal(),
      ?_topShare(),
      ?_noSpendDays(),
      ?_savings(),
      ?_monthTotal(),
    ];
    _p.shuffle(rest);
    return [...urgent, ...rest];
  }

  // A bill due within four days of [fireAt], noting a short balance.
  ReminderText? _obligation(DateTime fireAt) {
    final day = _day(fireAt);
    final upcoming = facts.obligations.where((item) {
      final due = _day(item.nextDueAt).difference(day).inDays;
      return due >= 0 && due <= 4;
    }).toList()..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    if (upcoming.isEmpty) return null;
    final next = upcoming.first;
    final name = Ar.quote(next.name);
    final due = _day(next.nextDueAt).difference(day).inDays;
    final when = switch (due) {
      0 => 'اليوم',
      1 => 'غداً',
      _ => 'بعد ${Ar.days.of(due)}',
    };
    final short = next.amount > facts.balance;
    return (
      kind: 'obligation',
      title: _p.pick([
        '$name مستحق $when',
        'موعد $name $when',
        '$when: دفعة $name',
      ]),
      body: short
          ? _p.pick([
              'المبلغ ${_p.money(next.amount)}، ورصيدك الحالي ${_p.money(facts.balance)}.',
              'المبلغ ${_p.money(next.amount)}، وهو أكبر من رصيدك الحالي.',
            ])
          : _p.pick([
              'المبلغ ${_p.money(next.amount)}.',
              'قيمة الدفعة ${_p.money(next.amount)}.',
              'سيُخصم ${_p.money(next.amount)} من رصيدك.',
            ]),
    );
  }

  // Two bills or more due in the seven days from [fireAt].
  ReminderText? _paymentsAhead(DateTime fireAt) {
    final day = _day(fireAt);
    final week = facts.obligations.where((item) {
      final due = _day(item.nextDueAt).difference(day).inDays;
      return due >= 0 && due < 7;
    }).toList();
    if (week.length < 2) return null;
    final total = week.fold(0.0, (sum, item) => sum + item.amount);
    final count = Ar.payments.of(week.length);
    return (
      kind: 'payments',
      title: _p.pick(
        [
          '$count خلال الأيام السبعة القادمة',
          'أسبوع فيه $count مستحقة',
        ].where((text) => week.length > 2 || text.startsWith(count)).toList(),
      ),
      body: _p.pick([
        'مجموعها ${_p.money(total)}.',
        'بإجمالي ${_p.money(total)}.',
      ]),
    );
  }

  // The balance will run out before the next income at the recent pace.
  ReminderText? _shortBalance(DateTime fireAt) {
    final income = facts.daysUntilIncome;
    final runway = facts.runwayDays;
    if (income == null || runway == null || facts.balance <= 0) return null;
    final passed = _offset(fireAt);
    final incomeLeft = income - passed;
    final runwayLeft = (runway - passed).floor();
    if (incomeLeft < 2 || runwayLeft >= incomeLeft - 1) return null;
    final lasting = runwayLeft <= 0
        ? 'قد يكون نفد الآن'
        : 'يكفي نحو ${Ar.days.of(runwayLeft)}';
    return (
      kind: 'short-balance',
      title: _p.pick([
        'رصيدك قد لا يكفي حتى الدخل',
        'رصيدك أقصر من المدة المتبقية حتى الدخل',
      ]),
      body: _p.pick([
        'بالوتيرة الأخيرة $lasting، والدخل بعد ${Ar.days.of(incomeLeft)}.',
        'الحد اليومي الذي يوصلك إلى الدخل ${_p.money(facts.balance / incomeLeft)}.',
      ]),
    );
  }

  // The balance, the days to the next income, and the daily allowance.
  ReminderText? _balance(DateTime fireAt) {
    final income = facts.daysUntilIncome;
    if (income == null || facts.balance <= 0) return null;
    final left = income - _offset(fireAt);
    if (left < 2) return null;
    final perDay = _p.money(facts.balance / left);
    final balance = _p.money(facts.balance);
    final days = Ar.days.of(left);
    // Title and body are paired so neither repeats the other.
    final (title, body) = _p.pick([
      (
        'متبقٍّ في رصيدك $balance',
        'والدخل القادم بعد $days، أي نحو $perDay لكل يوم.',
      ),
      ('رصيدك الحالي $balance', 'ما يعادل $perDay يومياً حتى الدخل القادم.'),
      ('الدخل القادم بعد $days', 'ورصيدك $balance، بمعدل $perDay لليوم.'),
    ]);
    return (kind: 'balance', title: title, body: body);
  }

  // The category that grew most against last month (over 30%).
  ReminderText? _categoryChange() {
    MapEntry<String, double>? top;
    var growth = 0.0;
    for (final entry in facts.monthCategories.entries) {
      final before = facts.prevMonthCategories[entry.key] ?? 0;
      if (before <= 0) continue;
      final change = (entry.value - before) / before;
      if (change > 0.3 && change > growth) {
        top = entry;
        growth = change;
      }
    }
    if (top == null) return null;
    final name = Ar.category(top.key);
    final before = facts.prevMonthCategories[top.key]!;
    return (
      kind: 'category',
      title: _p.pick([
        'صرفك على $name أعلى بنسبة ${_p.percent(growth)}',
        'ارتفاع في صرف $name',
        '$name يرتفع بنسبة ${_p.percent(growth)}',
      ]),
      body: _p.pick([
        '${_p.money(top.value)} هذا الشهر مقابل ${_p.money(before)} في الفترة نفسها من الشهر الماضي.',
        'الفارق عن الشهر الماضي ${_p.money(top.value - before)} حتى الآن.',
        'بلغ ${_p.money(top.value)} بعد أن كان ${_p.money(before)} في الفترة نفسها.',
      ]),
    );
  }

  // The active goal closest to done.
  ReminderText? _goal() {
    final active = facts.goals.where((goal) => goal.ratio < 1).toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));
    if (active.isEmpty) return null;
    final goal = active.first;
    final name = Ar.quote(goal.name);
    return (
      kind: 'goal',
      title: _p.pick([
        '$name وصل إلى ${_p.percent(goal.ratio)}',
        'هدفك $name: ${_p.percent(goal.ratio)}',
        goal.ratio >= 0.8
            ? '$name على وشك الاكتمال'
            : 'أنجزت ${_p.percent(goal.ratio)} من $name',
      ]),
      body: _p.pick([
        'بقي ${_p.money(goal.remaining)} على الهدف.',
        'تم توفير ${_p.money(goal.saved)} من أصل ${_p.money(goal.target)}.',
        'المتبقي لإكماله ${_p.money(goal.remaining)}.',
      ]),
    );
  }

  // One category taking 30% of the month's spending or more.
  ReminderText? _topShare() {
    if (facts.monthSpent <= 0 || facts.monthCategories.length < 2) return null;
    final top = largestCategory(facts.monthCategories)!;
    final share = top.value / facts.monthSpent;
    if (share < 0.3) return null;
    final name = Ar.category(top.key);
    return (
      kind: 'top-share',
      title: _p.pick([
        '$name يمثّل ${_p.percent(share)} من صرف الشهر',
        'الحصة الأكبر هذا الشهر ${Ar.li(name)}',
      ]),
      body: _p.pick([
        'بمبلغ ${_p.money(top.value)} حتى الآن.',
        'أي ${_p.money(top.value)} من أصل ${_p.money(facts.monthSpent)}.',
      ]),
    );
  }

  // Days without spending this month (from the 7th, three or more).
  ReminderText? _noSpendDays() {
    if (facts.dayOfMonth < 7) return null;
    final days = facts.noSpendDaysThisMonth;
    if (days < 3 || facts.dailyAverageThisMonth <= 0) return null;
    final saved = _p.money(days * facts.dailyAverageThisMonth);
    return (
      kind: 'no-spend',
      title: _p.pick([
        '${Ar.days.of(days)} بلا صرف هذا الشهر',
        'مرّت ${Ar.days.of(days)} هذا الشهر دون أي مصروف',
      ]),
      body: _p.pick([
        'وهذا يعادل نحو $saved بحسب متوسطك اليومي.',
        'أي ما يعادل نحو $saved بمتوسط صرفك اليومي.',
      ]),
    );
  }

  // The savings balance and how long it would cover normal spending.
  ReminderText? _savings() {
    if (facts.savingsBalance <= 0) return null;
    final daily = facts.dailyAverageRecent;
    final String body;
    if (daily > 0) {
      final days = (facts.savingsBalance / daily).floor();
      final cover = days >= 60
          ? Ar.months.of(days ~/ 30)
          : Ar.days.of(math.max(1, days));
      body = _p.pick([
        'يغطي صرفك المعتاد لمدة $cover تقريباً.',
        'وهو ما يكفي لنحو $cover من صرفك الحالي.',
      ]);
    } else {
      body = _p.pick([
        'محفوظ بعيداً عن الصرف اليومي.',
        'مبلغ جاهز لأهدافك القادمة.',
      ]);
    }
    return (
      kind: 'savings',
      title: _p.pick([
        'رصيد توفيرك ${_p.money(facts.savingsBalance)}',
        'لديك ${_p.money(facts.savingsBalance)} في التوفير',
      ]),
      body: body,
    );
  }

  // The month's total so far and its biggest category.
  ReminderText? _monthTotal() {
    if (facts.monthSpent <= 0) return null;
    final top = largestCategory(facts.monthCategories);
    return (
      kind: 'month',
      title: _p.pick([
        'صرفك هذا الشهر ${_p.money(facts.monthSpent)}',
        'إجمالي الشهر حتى الآن ${_p.money(facts.monthSpent)}',
      ]),
      body: top == null
          ? 'بمعدل ${_p.money(facts.dailyAverageThisMonth)} يومياً.'
          : _p.pick([
              'أكبر بند ${Ar.category(top.key)} بنسبة ${_p.percent(top.value / facts.monthSpent)}.',
              'بمعدل ${_p.money(facts.dailyAverageThisMonth)} يومياً.',
            ]),
    );
  }

  /// The Friday summary of the current week, or null with nothing spent.
  ReminderText? weekly() {
    final now = facts.weekSpent;
    if (now <= 0) return null;
    final before = facts.prevWeekSpentSameSpan;
    final String body;
    if (before > 0 && (now - before).abs() / before >= 0.1) {
      final change = (now - before) / before;
      body = change > 0
          ? _p.pick([
              'أكثر بنسبة ${_p.percent(change)} من الأسبوع الماضي.',
              'بزيادة ${_p.money(now - before)} عن الأسبوع الماضي.',
            ])
          : _p.pick([
              'أقل بنسبة ${_p.percent(change)} من الأسبوع الماضي.',
              'بتوفير ${_p.money(before - now)} مقارنةً بالأسبوع الماضي.',
            ]);
    } else {
      body = _p.pick([
        'قريب من صرف الأسبوع الماضي.',
        'في مستوى الأسبوع الماضي تقريباً.',
      ]);
    }
    return (
      kind: 'weekly',
      title: _p.pick([
        'صرفك هذا الأسبوع ${_p.money(now)}',
        'حصيلة أسبوعك: ${_p.money(now)}',
        'أسبوعك في رقم: ${_p.money(now)}',
      ]),
      body: body,
    );
  }

  /// The evening streak reminder, written as a fact about the streak.
  /// Needs no ledger, so it can be written without SmartFacts.
  static ReminderText streakText(int count, {int? seed}) {
    final phrasing = InsightPhrasing('', math.Random(seed));
    final run = Ar.consecutiveDays.of(count);
    return (
      kind: 'streak',
      title: phrasing.pick([
        'سلسلة من $run في وفّر',
        'سلسلتك مستمرة منذ ${Ar.days.of(count)}',
      ]),
      body: phrasing.pick([
        'يوم إضافي يرفعها إلى ${Ar.days.of(count + 1)}.',
        'يوم آخر يجعلها ${Ar.days.of(count + 1)}.',
      ]),
    );
  }
}
