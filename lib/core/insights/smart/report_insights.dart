// Report-scope insight rules: where the money goes. Each rule checks one
// pattern in the numbers and, when it applies, writes one insight card.

import 'package:flutter/material.dart';
import 'package:waffr/core/insights/smart/arabic_text.dart';
import 'package:waffr/core/insights/smart/insight_phrasing.dart';
import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';

/// The category with the largest total in [totals], or null when empty.
MapEntry<String, double>? largestCategory(Map<String, double> totals) {
  if (totals.isEmpty) return null;
  return totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
}

/// Rules for the reports screen: trends, categories, pace and bills.
class ReportInsights {
  /// Rules over [facts], worded through the run's shared phrasing.
  ReportInsights(this.facts, this._p);

  /// The numbers of this run.
  final SmartFacts facts;

  final InsightPhrasing _p;

  /// Every report rule that applies, in a fixed order (the order keeps
  /// seeded runs stable). With no expenses only the "start logging" card.
  List<SmartInsight> all() {
    if (!facts.hasExpenses) return [_noExpensesYet()];
    return [
      ?_monthTrend(),
      ?_weekTrend(),
      ?_topCategory(),
      ?_categorySpike(),
      ?_categoryDrop(),
      ?_projection(),
      ?_runway(),
      ?_weekdayPeak(),
      ?_smallExpenses(),
      ?_largestExpense(),
      ?_noSpendDays(),
      ?_paymentMix(),
      ?_nightSpending(),
      ?_uncategorized(),
      ?_obligationsSoon(),
      ?_obligationsShare(),
    ];
  }

  // Nothing logged yet: invite the first expense.
  SmartInsight _noExpensesYet() => SmartInsight(
    id: 'no-expenses',
    tone: InsightTone.tip,
    icon: Icons.edit_note_rounded,
    title: _p.pick([
      'ابدأ بأول مصروف',
      'التحليل بانتظار بياناتك',
      'سجّل مصاريفك لأفهم عاداتك',
    ]),
    body: _p.pick([
      'لا توجد مصاريف مسجّلة بعد. سجّل ما تصرفه يومياً، وسأبدأ بإظهار وجهة أموالك وطرق التوفير.',
      'كل مصروف تسجّله يجعل التحليل أدق. ابدأ اليوم ولو بمصروف صغير.',
      'بعد أسبوع من التسجيل ستظهر هنا مقارنات واتجاهات ونصائح مصمّمة لك.',
    ]),
    priority: 100,
    action: InsightAction.addExpense,
  );

  // This month so far against the same days of last month (from the 3rd).
  SmartInsight? _monthTrend() {
    final now = facts.monthSpent;
    final before = facts.prevMonthSpentSameSpan;
    if (now <= 0 || before <= 0 || facts.dayOfMonth < 3) return null;
    final change = (now - before) / before;
    final detail =
        'هذا الشهر حتى اليوم: ${_p.money(now)}\nالشهر الماضي في الفترة نفسها: ${_p.money(before)}';

    if (change > 0.10) {
      return SmartInsight(
        id: 'month-trend',
        tone: InsightTone.warning,
        icon: Icons.trending_up_rounded,
        title: _p.pick([
          'صرفك أعلى من الشهر الماضي',
          'الصرف في ارتفاع',
          'زيادة بنسبة ${_p.percent(change)} عن الشهر الماضي',
          'وتيرة صرف أسرع من المعتاد',
        ]),
        body: _p.say(InsightTone.warning, [
          'صرفت ${_p.money(now)} حتى الآن، أي أكثر بنسبة ${_p.percent(change)} من الفترة نفسها في الشهر الماضي.',
          'مقارنةً بالأيام نفسها من الشهر الماضي، ارتفع صرفك بنسبة ${_p.percent(change)}. راجع أكبر تصنيفاتك لتعرف السبب.',
          'تسير مصاريفك هذا الشهر أسرع من المعتاد بنسبة ${_p.percent(change)}، والفارق حتى الآن ${_p.money(now - before)}.',
          'ارتفع إجمالي صرفك من ${_p.money(before)} إلى ${_p.money(now)} مقارنةً بالفترة نفسها من الشهر الماضي.',
        ]),
        detail: detail,
        priority: 80 + (change * 20).clamp(0, 15).round(),
      );
    }
    if (change < -0.10) {
      return SmartInsight(
        id: 'month-trend',
        tone: InsightTone.positive,
        icon: Icons.trending_down_rounded,
        title: _p.pick([
          'أحسنت! صرفك أقل',
          'انخفاض بنسبة ${_p.percent(change)} في الصرف',
          'شهر أوفر من سابقه',
          'مصاريفك في تراجع',
        ]),
        body: _p.say(InsightTone.positive, [
          'صرفت ${_p.money(now)} حتى الآن، أي أقل بنسبة ${_p.percent(change)} من الفترة نفسها في الشهر الماضي.',
          'تحسّن واضح: وفّرت ${_p.money(before - now)} مقارنةً بالأيام نفسها من الشهر الماضي.',
          'انخفض صرفك هذا الشهر بنسبة ${_p.percent(change)}، ويمكنك تحويل الفارق إلى التوفير.',
          'تراجع إجمالي صرفك من ${_p.money(before)} إلى ${_p.money(now)} في الفترة المماثلة.',
        ]),
        detail: detail,
        priority: 70,
      );
    }
    return SmartInsight(
      id: 'month-trend',
      tone: InsightTone.info,
      icon: Icons.drag_handle_rounded,
      title: _p.pick([
        'صرف مستقر',
        'الوتيرة نفسها كالشهر الماضي',
        'لا تغيير يُذكر',
      ]),
      body: _p.say(InsightTone.info, [
        'صرفك هذا الشهر قريب من الشهر الماضي: ${_p.money(now)} مقابل ${_p.money(before)}.',
        'وتيرتك ثابتة تقريباً مقارنةً بالشهر الماضي. الثبات جيد، والخطوة التالية خفض تصنيف واحد.',
        'لا فرق كبير بين هذا الشهر والذي قبله في الفترة نفسها.',
      ]),
      detail: detail,
      priority: 40,
    );
  }

  // This week against the same days of last week; swings of 25% or more.
  SmartInsight? _weekTrend() {
    final now = facts.weekSpent;
    final before = facts.prevWeekSpentSameSpan;
    if (now <= 0 || before <= 0) return null;
    final change = (now - before) / before;
    if (change.abs() < 0.25) return null;
    final up = change > 0;
    final tone = up ? InsightTone.warning : InsightTone.positive;
    return SmartInsight(
      id: 'week-trend',
      tone: tone,
      icon: up ? Icons.north_east_rounded : Icons.south_east_rounded,
      title: up
          ? _p.pick([
              'أسبوع أغلى من سابقه',
              'ارتفاع في صرف هذا الأسبوع',
              'الأسبوع الحالي مكلف',
            ])
          : _p.pick(['أسبوع أوفر', 'هذا الأسبوع أهدأ', 'صرف أسبوعي أقل']),
      body: up
          ? _p.say(tone, [
              'صرفت هذا الأسبوع ${_p.money(now)}، أي أكثر بنسبة ${_p.percent(change)} من الأيام نفسها في الأسبوع الماضي.',
              'يسير هذا الأسبوع أسرع بنسبة ${_p.percent(change)} من الأسبوع الماضي، وما زال أمامك وقت لتعديل المسار.',
            ])
          : _p.say(tone, [
              'صرفت هذا الأسبوع ${_p.money(now)}، أي أقل بنسبة ${_p.percent(change)} من الأسبوع الماضي.',
              'أسبوع جيد! انخفض صرفك بنسبة ${_p.percent(change)} مقارنةً بالأسبوع الماضي.',
            ]),
      detail:
          'هذا الأسبوع: ${_p.money(now)}\nالأسبوع الماضي في الأيام نفسها: ${_p.money(before)}',
      priority: up ? 62 : 48,
    );
  }

  // One category taking 30% or more of this month's spending.
  SmartInsight? _topCategory() {
    final top = largestCategory(facts.monthCategories);
    if (top == null || facts.monthSpent <= 0) return null;
    final share = top.value / facts.monthSpent;
    if (share < 0.3 || facts.monthCategories.length < 2) return null;
    final name = Ar.category(top.key);
    final tone = share > 0.5 ? InsightTone.warning : InsightTone.info;
    return SmartInsight(
      id: 'top-category',
      tone: tone,
      icon: Icons.pie_chart_outline_rounded,
      title: _p.pick([
        '$name يستحوذ على الحصة الأكبر',
        '${_p.percent(share)} من صرفك على $name',
        'أكبر تصنيف هذا الشهر: $name',
      ]),
      body: _p.say(tone, [
        'أنفقت ${_p.money(top.value)} على $name هذا الشهر، أي ${_p.percent(share)} من إجمالي صرفك.',
        '$name وحده يمثّل ${_p.percent(share)} من مصاريفك، وخفضه بنسبة ${_p.percent(0.1)} يوفّر ${_p.money(top.value * 0.1)}.',
        'إن أردت أثراً سريعاً في ميزانيتك فابدأ ب$name، إذ صرفت عليه ${_p.money(top.value)} حتى الآن.',
      ]),
      detail: [
        for (final entry
            in (facts.monthCategories.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(4))
          '${entry.key}: ${_p.money(entry.value)} (${_p.percent(entry.value / facts.monthSpent)})',
      ].join('\n'),
      priority: share > 0.5 ? 72 : 55,
    );
  }

  // The category that grew most: over 30%, and at least a tenth of the
  // month's spending.
  SmartInsight? _categorySpike() {
    MapEntry<String, double>? worst;
    var worstGrowth = 0.0;
    for (final entry in facts.monthCategories.entries) {
      final before = facts.prevMonthCategories[entry.key] ?? 0;
      if (before <= 0) continue;
      final growth = (entry.value - before) / before;
      final significant = entry.value - before >= facts.monthSpent * 0.1;
      if (growth > 0.3 && significant && growth > worstGrowth) {
        worst = entry;
        worstGrowth = growth;
      }
    }
    if (worst == null) return null;
    final before = facts.prevMonthCategories[worst.key]!;
    final name = Ar.category(worst.key);
    return SmartInsight(
      id: 'category-spike',
      tone: InsightTone.warning,
      icon: Icons.warning_amber_rounded,
      title: _p.pick([
        'ارتفاع الصرف على $name بنسبة ${_p.percent(worstGrowth)}',
        'قفزة في $name',
        'انتبه للصرف على $name',
        '$name أعلى بكثير من المعتاد',
      ]),
      body: _p.say(InsightTone.warning, [
        'صرفت على $name ${_p.money(worst.value)} مقابل ${_p.money(before)} في الفترة نفسها من الشهر الماضي.',
        'زاد صرفك على $name بمقدار ${_p.money(worst.value - before)} عن الشهر الماضي. هل هو مصروف طارئ أم عادة جديدة؟',
        'سجّل $name أكبر زيادة هذا الشهر بنسبة ${_p.percent(worstGrowth)}، فحدّد له سقفاً أسبوعياً.',
      ]),
      detail:
          'هذا الشهر: ${_p.money(worst.value)}\nالشهر الماضي في الفترة نفسها: ${_p.money(before)}',
      priority: 85,
      action: InsightAction.expenseHistory,
    );
  }

  // The category that fell most: by a quarter, worth 8% of last month's
  // same span.
  SmartInsight? _categoryDrop() {
    MapEntry<String, double>? best;
    var bestSaving = 0.0;
    for (final entry in facts.prevMonthCategories.entries) {
      final now = facts.monthCategories[entry.key] ?? 0;
      final saving = entry.value - now;
      if (now < entry.value * 0.75 &&
          saving > bestSaving &&
          saving >= facts.prevMonthSpentSameSpan * 0.08) {
        best = entry;
        bestSaving = saving;
      }
    }
    if (best == null) return null;
    final name = Ar.category(best.key);
    return SmartInsight(
      id: 'category-drop',
      tone: InsightTone.positive,
      icon: Icons.thumb_up_alt_outlined,
      title: _p.pick([
        'تحسّن في $name',
        'وفّرت على $name',
        'صرف أقل على $name',
      ]),
      body: _p.say(InsightTone.positive, [
        'صرفك على $name أقل بمقدار ${_p.money(bestSaving)} من الفترة نفسها في الشهر الماضي.',
        'نجحت في خفض الصرف على $name، والفارق حتى الآن ${_p.money(bestSaving)}.',
        'وفّر عليك تراجع $name مبلغ ${_p.money(bestSaving)}، ففكّر في تحويله إلى التوفير.',
      ]),
      priority: 58,
      action: InsightAction.manualSave,
    );
  }

  // Month-end spending at the recent pace, against income when known.
  SmartInsight? _projection() {
    if (facts.dayOfMonth < 5 || facts.monthSpent <= 0) return null;
    final projected = facts.projectedMonthSpend;
    final income = facts.effectiveMonthlyIncome;
    final detail =
        'متوسطك اليومي الأخير: ${_p.money(facts.dailyAverageRecent)}\n'
        'المتبقي من الشهر: ${_p.days(facts.daysLeftInMonth)}\n'
        'التوقع لنهاية الشهر: ${_p.money(projected)}';

    if (income != null && projected > income) {
      return SmartInsight(
        id: 'projection',
        tone: InsightTone.warning,
        icon: Icons.insights_rounded,
        title: _p.pick([
          'التوقع يتجاوز دخلك',
          'بهذه الوتيرة ستتخطى دخلك',
          'نهاية الشهر تحتاج إلى انتباه',
        ]),
        body: _p.say(InsightTone.warning, [
          'إذا استمر صرفك بالوتيرة نفسها فسيبلغ ${_p.money(projected)} في نهاية الشهر، بينما دخلك ${_p.money(income)}.',
          'أتوقع أن يصل صرفك إلى ${_p.money(projected)} في نهاية الشهر، أي أكثر من دخلك بمقدار ${_p.money(projected - income)}.',
        ]),
        detail: detail,
        priority: 88,
      );
    }
    final tone = income != null && projected < income * 0.8
        ? InsightTone.positive
        : InsightTone.info;
    return SmartInsight(
      id: 'projection',
      tone: tone,
      icon: Icons.insights_rounded,
      title: _p.pick([
        'توقّع نهاية الشهر',
        'إلى أين يتجه صرفك؟',
        'نظرة على بقية الشهر',
      ]),
      body: income != null
          ? _p.say(tone, [
              'بهذه الوتيرة سيكون صرفك نحو ${_p.money(projected)} من أصل دخل قدره ${_p.money(income)}.',
              'من المتوقع أن تنهي الشهر بصرف ${_p.money(projected)}، ويبقى لك تقريباً ${_p.money(income - projected)}.',
            ])
          : _p.say(tone, [
              'بهذه الوتيرة سيبلغ صرفك نحو ${_p.money(projected)} مع نهاية الشهر.',
              'متوسطك اليومي ${_p.money(facts.dailyAverageRecent)}، أي قرابة ${_p.money(projected)} للشهر كاملاً.',
            ]),
      detail: detail,
      priority: 52,
    );
  }

  // Whether the balance lasts until the next income at the recent pace.
  SmartInsight? _runway() {
    final runway = facts.runwayDays;
    final untilIncome = facts.daysUntilIncome;
    if (runway == null || untilIncome == null || untilIncome <= 0) return null;
    if (facts.balance <= 0) {
      return SmartInsight(
        id: 'runway',
        tone: InsightTone.warning,
        icon: Icons.account_balance_wallet_outlined,
        title: _p.pick(['نفد رصيدك', 'الرصيد صفر']),
        body:
            'لم يبقَ رصيد حتى الدخل القادم بعد ${_p.days(untilIncome)}، فأجّل غير الضروري إن استطعت.',
        priority: 95,
      );
    }
    final dailyLimit = facts.balance / untilIncome;
    final detail =
        'الرصيد الحالي: ${_p.money(facts.balance)}\n'
        'متوسطك اليومي الأخير: ${_p.money(facts.dailyAverageRecent)}\n'
        'الدخل القادم بعد: ${_p.days(untilIncome)}';
    if (runway < untilIncome) {
      final gap = (untilIncome - runway).ceil();
      return SmartInsight(
        id: 'runway',
        tone: InsightTone.warning,
        icon: Icons.hourglass_bottom_rounded,
        title: _p.pick([
          'قد ينفد الرصيد قبل الدخل',
          'انتبه: ${_p.days(gap)} بلا رصيد',
          'وتيرتك أسرع من رصيدك',
        ]),
        body: _p.say(InsightTone.warning, [
          'بهذه الوتيرة سينفد رصيدك قبل الدخل القادم بنحو ${_p.days(gap)}، فحاول ألا تتجاوز ${_p.money(dailyLimit)} يومياً.',
          'يكفي رصيدك ${runway < 1 ? '' : 'قرابة '}${_p.days(runway.floor())} فقط، والدخل بعد ${_p.days(untilIncome)}. حدّك اليومي الآمن ${_p.money(dailyLimit)}.',
          'لتصل إلى الدخل القادم بأمان، اجعل صرفك اليومي نحو ${_p.money(dailyLimit)} بدلاً من ${_p.money(facts.dailyAverageRecent)}.',
        ]),
        detail: detail,
        priority: 92,
      );
    }
    return SmartInsight(
      id: 'runway',
      tone: InsightTone.positive,
      icon: Icons.verified_outlined,
      title: _p.pick([
        'رصيدك يكفي حتى الدخل',
        'وضعك آمن حتى الدخل القادم',
        'أنت على المسار الصحيح',
      ]),
      body: _p.say(InsightTone.positive, [
        'بوتيرتك الحالية يكفي رصيدك حتى الدخل القادم بعد ${_p.days(untilIncome)}، ويمكنك صرف ما يصل إلى ${_p.money(dailyLimit)} يومياً.',
        'يغطي رصيدك قرابة ${_p.days(runway.floor())}، والدخل بعد ${_p.days(untilIncome)}، وما يزيد يمكنك توفيره.',
      ]),
      detail: detail,
      priority: 50,
    );
  }

  // A weekday costing 1.6 times the daily average or more (three weeks of
  // history needed).
  SmartInsight? _weekdayPeak() {
    if (facts.weeksOfHistory < 3) return null;
    final totals = facts.weekdayTotals;
    if (totals.length < 4) return null;
    final average = totals.values.reduce((a, b) => a + b) / 7;
    final peak = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (average <= 0 || peak.value < average * 1.6) return null;
    final day = Ar.weekdays[peak.key]!;
    final ratio = (peak.value / average).toStringAsFixed(1);
    return SmartInsight(
      id: 'weekday-peak',
      tone: InsightTone.tip,
      icon: Icons.calendar_month_outlined,
      title: _p.pick([
        'يوم $day هو الأغلى',
        'نمط أسبوعي: يوم $day',
        'تصرف أكثر أيام $day',
      ]),
      body: _p.say(InsightTone.tip, [
        'خلال الأسابيع الماضية كان يوم $day الأعلى صرفاً بفارق واضح عن بقية الأيام.',
        'يقارب صرفك يوم $day \u2066$ratio\u2069 أضعاف متوسط اليوم، فخطّط له مسبقاً.',
        'لاحظت أن يوم $day يتكرر بوصفه أغلى أيام أسبوعك، وميزانية صغيرة لهذا اليوم قد تُحدث فرقاً.',
      ]),
      priority: 45,
    );
  }

  // Small amounts (under 40% of the average expense) adding up to 12% of
  // the month or more.
  SmartInsight? _smallExpenses() {
    final month = facts.expensesBetween(
      facts.monthStart,
      facts.today.add(const Duration(days: 1)),
    );
    if (month.length < 6) return null;
    final average = facts.monthSpent / month.length;
    final small = month.where((e) => e.amount <= average * 0.4).toList();
    final sum = small.fold(0.0, (total, e) => total + e.amount);
    if (small.length < 5 || sum < facts.monthSpent * 0.12) return null;
    final counted = Ar.smallExpenses.of(small.length);
    return SmartInsight(
      id: 'small-expenses',
      tone: InsightTone.tip,
      icon: Icons.local_cafe_outlined,
      title: _p.pick([
        'المصاريف الصغيرة تتراكم',
        '$counted هذا الشهر',
        'انتبه للمبالغ الصغيرة',
      ]),
      body: _p.say(InsightTone.tip, [
        'سجّلت $counted مجموعها ${_p.money(sum)}، أي ${_p.percent(sum / facts.monthSpent)} من صرفك.',
        'بلغت المبالغ الصغيرة المتكررة ${_p.money(sum)} هذا الشهر، وقد تكون أسهل مكان للتوفير.',
        'يبدو كل مصروف صغير بسيطاً، لكن $counted صنعت معاً ${_p.money(sum)}.',
      ]),
      priority: 54,
    );
  }

  // One expense worth a quarter of the month or more.
  SmartInsight? _largestExpense() {
    final month = facts.expensesBetween(
      facts.monthStart,
      facts.today.add(const Duration(days: 1)),
    );
    if (month.length < 3) return null;
    final biggest = month.reduce((a, b) => a.amount >= b.amount ? a : b);
    final share = biggest.amount / facts.monthSpent;
    if (share < 0.25) return null;
    final note = biggest.note?.trim() ?? '';
    final label = note.isNotEmpty
        ? Ar.quote(note)
        : 'في ${Ar.category(biggest.category ?? 'أخرى')}';
    return SmartInsight(
      id: 'largest-expense',
      tone: InsightTone.info,
      icon: Icons.receipt_long_outlined,
      title: _p.pick(['مصروف كبير واحد', 'أكبر مصروف هذا الشهر']),
      body: _p.say(InsightTone.info, [
        'يمثّل مصروفك $label بقيمة ${_p.money(biggest.amount)} نسبة ${_p.percent(share)} من صرفك هذا الشهر.',
        'استحوذ مصروف واحد ($label، ${_p.money(biggest.amount)}) على ${_p.percent(share)} من صرف الشهر. إن كان متوقعاً فخطّط له في الأشهر القادمة.',
      ]),
      priority: 44,
      action: InsightAction.expenseHistory,
    );
  }

  // Days without spending this month (from the 7th, three or more).
  SmartInsight? _noSpendDays() {
    if (facts.dayOfMonth < 7) return null;
    final days = facts.noSpendDaysThisMonth;
    if (days < 3) return null;
    return SmartInsight(
      id: 'no-spend-days',
      tone: InsightTone.positive,
      icon: Icons.celebration_outlined,
      title: _p.pick([
        '${_p.days(days)} بلا صرف',
        'أيام خالية من الصرف',
        'تحدٍّ ناجح',
      ]),
      body: _p.say(InsightTone.positive, [
        'مرّت ${_p.days(days)} هذا الشهر دون أي مصروف، وهذه الأيام أسرع طريق إلى التوفير.',
        'لديك ${_p.days(days)} بلا صرف حتى الآن. جرّب أن تضيف يوماً واحداً كل أسبوع.',
      ]),
      priority: 42,
    );
  }

  // Card payments making up 70% of the month or more.
  SmartInsight? _paymentMix() {
    final month = facts.expensesBetween(
      facts.monthStart,
      facts.today.add(const Duration(days: 1)),
    );
    if (month.length < 6) return null;
    final card = month
        .where((e) => e.paymentMethod == 'بطاقة')
        .fold(0.0, (total, e) => total + e.amount);
    final share = facts.monthSpent <= 0 ? 0.0 : card / facts.monthSpent;
    if (share < 0.7) return null;
    return SmartInsight(
      id: 'payment-mix',
      tone: InsightTone.tip,
      icon: Icons.credit_card_rounded,
      title: _p.pick([
        'معظم صرفك بالبطاقة',
        '${_p.percent(share)} من صرفك بالبطاقة',
      ]),
      body: _p.say(InsightTone.tip, [
        'الدفع بالبطاقة يجعل الصرف أسهل وأقل إحساساً، فراجع مصاريف البطاقة أسبوعياً.',
        'دفعت ${_p.percent(share)} من صرفك هذا الشهر بالبطاقة، وقد يخفّض الدفع النقدي المصاريف الصغيرة.',
      ]),
      priority: 35,
    );
  }

  // A quarter of recent expenses or more made between 10 pm and 4 am.
  SmartInsight? _nightSpending() {
    final recent = facts.expensesBetween(
      facts.today.subtract(const Duration(days: 30)),
      facts.today.add(const Duration(days: 1)),
    );
    if (recent.length < 8) return null;
    final night = recent
        .where((e) => e.dateTime.hour >= 22 || e.dateTime.hour < 4)
        .toList();
    if (night.length < 4 || night.length / recent.length < 0.25) return null;
    final sum = night.fold(0.0, (total, e) => total + e.amount);
    return SmartInsight(
      id: 'night-spending',
      tone: InsightTone.tip,
      icon: Icons.nightlight_round,
      title: _p.pick(['صرف ليلي ملحوظ', 'السهر مكلف']),
      body: _p.say(InsightTone.tip, [
        'كان ${Ar.expenses.of(night.length)} من مصاريفك الأخيرة في وقت متأخر ليلاً، بمجموع ${_p.money(sum)}.',
        'جزء واضح من صرفك يحدث بعد العاشرة مساءً، وقرارات الليل غالباً أقل تخطيطاً.',
      ]),
      priority: 38,
    );
  }

  // A quarter of the month or more filed under «أخرى».
  SmartInsight? _uncategorized() {
    final other = facts.monthCategories['أخرى'] ?? 0;
    if (facts.monthSpent <= 0 || other / facts.monthSpent < 0.25) return null;
    return SmartInsight(
      id: 'uncategorized',
      tone: InsightTone.tip,
      icon: Icons.label_outline_rounded,
      title: _p.pick(['الكثير تحت «أخرى»', 'صنّف مصاريفك بدقة']),
      body: _p.say(InsightTone.tip, [
        'يقع ${_p.percent(other / facts.monthSpent)} من صرفك تحت تصنيف «أخرى»، وتصنيفه بدقة يجعل التحليل أوضح.',
        'كلما قلّ ما تضعه تحت «أخرى» كانت نصائحي أدق، فجرّب إنشاء تصنيف خاص لما يتكرر.',
      ]),
      priority: 40,
      action: InsightAction.expenseHistory,
    );
  }

  // Bills due within three days; a warning when they exceed the balance.
  SmartInsight? _obligationsSoon() {
    final soon = facts.obligations
        .where(
          (item) =>
              !item.nextDueAt.isBefore(facts.today) &&
              item.nextDueAt.isBefore(facts.today.add(const Duration(days: 4))),
        )
        .toList();
    if (soon.isEmpty) return null;
    final total = soon.fold(0.0, (sum, item) => sum + item.amount);
    final names = soon.map((item) => Ar.quote(item.name)).take(3).join('، ');
    final short = total > facts.balance;
    final tone = short ? InsightTone.warning : InsightTone.info;
    return SmartInsight(
      id: 'obligations-soon',
      tone: tone,
      icon: Icons.event_repeat_rounded,
      title: _p.pick(['التزامات خلال أيام', 'دفعات قادمة قريباً']),
      body: _p.say(tone, [
        'تستحق خلال الأيام القليلة القادمة: $names، بمجموع ${_p.money(total)}.',
        'جهّز ${_p.money(total)} لالتزامات قريبة: $names.',
      ]),
      priority: short ? 90 : 60,
      action: InsightAction.obligations,
    );
  }

  // Recurring bills taking 15% of income or more (heavy from 40%).
  SmartInsight? _obligationsShare() {
    final monthly = facts.obligationsMonthly;
    final income = facts.effectiveMonthlyIncome;
    if (monthly <= 0 || income == null || income <= 0) return null;
    final share = monthly / income;
    if (share < 0.15) return null;
    final heavy = share >= 0.4;
    final tone = heavy ? InsightTone.warning : InsightTone.info;
    return SmartInsight(
      id: 'obligations-share',
      tone: tone,
      icon: Icons.repeat_rounded,
      title: heavy
          ? _p.pick(['الالتزامات ثقيلة', 'التزاماتك تستهلك الكثير'])
          : _p.pick(['التزاماتك الشهرية', 'حصة الالتزامات من الدخل']),
      body: heavy
          ? _p.say(tone, [
              'تستهلك التزاماتك المتكررة (${_p.money(monthly)} شهرياً) ${_p.percent(share)} من دخلك، فراجع ما يمكن إلغاؤه أو تخفيضه.',
              'يذهب ${_p.percent(share)} من دخلك إلى التزامات ثابتة، وحتى اشتراك واحد أقل يصنع فرقاً.',
            ])
          : _p.say(tone, [
              'تبلغ التزاماتك المتكررة نحو ${_p.money(monthly)} شهرياً، أي ${_p.percent(share)} من دخلك.',
              'تدفع شهرياً قرابة ${_p.money(monthly)} التزامات ثابتة، وهي ${_p.percent(share)} من الدخل.',
            ]),
      priority: heavy ? 75 : 36,
      action: InsightAction.obligations,
    );
  }
}
