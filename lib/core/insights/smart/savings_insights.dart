// Savings-scope insight rules: goals, saving rate and habits.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waffr/core/insights/smart/arabic_text.dart';
import 'package:waffr/core/insights/smart/insight_phrasing.dart';
import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';

/// Rules for the savings screen.
class SavingsInsights {
  /// Rules over [facts], worded through the run's shared phrasing.
  SavingsInsights(this.facts, this._p);

  /// The numbers of this run.
  final SmartFacts facts;

  final InsightPhrasing _p;

  /// Every savings rule that applies, in a fixed order.
  List<SmartInsight> all() {
    return [
      ?_noGoals(),
      ..._goalInsights(),
      ?_stalledGoal(),
      ?_savingsRate(),
      ?_savingSuggestion(),
      ?_withdrawals(),
      ?_leftoverHabit(),
      ?_completedGoals(),
      ?_emergencyFund(),
      ?_shoppingList(),
    ];
  }

  // No goal yet: suggest creating one.
  SmartInsight? _noGoals() {
    if (facts.goals.isNotEmpty) return null;
    return SmartInsight(
      id: 'no-goals',
      tone: InsightTone.tip,
      icon: Icons.flag_outlined,
      title: _p.pick([
        'لا يوجد هدف بعد',
        'حدّد هدفك الأول',
        'التوفير أسهل مع هدف',
      ]),
      body: _p.say(InsightTone.tip, [
        'الأهداف تحوّل التوفير من نيّة إلى خطة، فابدأ بهدف صغير لشهر واحد.',
        'من يوفّر لهدف واضح يوفّر أكثر. ما الشيء الذي تريده خلال الأشهر القادمة؟',
        'أنشئ هدفاً، وسأتابع تقدّمك وأخبرك إن كنت على المسار.',
      ]),
      priority: 80,
      action: InsightAction.createGoal,
    );
  }

  // Up to three goals: nearly done, past due, behind pace, or on track.
  List<SmartInsight> _goalInsights() {
    final results = <SmartInsight>[];
    final pace = facts.goals.isEmpty
        ? 0.0
        : facts.averageMonthlySaving / facts.goals.length;
    for (final goal in facts.goals.take(3)) {
      if (goal.ratio >= 1) continue;
      final name = Ar.quote(goal.name);
      final detail =
          'الهدف: ${_p.money(goal.target)}\nتم توفير: ${_p.money(goal.saved)}\n'
          'المتبقي: ${_p.money(goal.remaining)}';

      if (goal.ratio >= 0.8) {
        results.add(
          SmartInsight(
            id: 'goal-near-${goal.id}',
            tone: InsightTone.positive,
            icon: Icons.emoji_events_outlined,
            title: _p.pick([
              'اقتربت من $name',
              '$name على وشك الاكتمال',
              'أنجزت ${_p.percent(goal.ratio)} من $name',
            ]),
            body: _p.say(InsightTone.positive, [
              'بقي ${_p.money(goal.remaining)} فقط لتحقيق $name. دفعة أخيرة!',
              'أنجزت ${_p.percent(goal.ratio)} من $name، وخطوة صغيرة تفصلك عن الوصول.',
            ]),
            detail: detail,
            priority: 74,
            action: InsightAction.manualSave,
          ),
        );
        continue;
      }

      final monthsToDeadline =
          goal.deadline.difference(facts.today).inDays / 30;
      if (monthsToDeadline <= 0) {
        results.add(
          SmartInsight(
            id: 'goal-late-${goal.id}',
            tone: InsightTone.warning,
            icon: Icons.event_busy_outlined,
            title: _p.pick(['انتهى موعد $name', '$name تجاوز موعده']),
            body: _p.say(InsightTone.warning, [
              'انتهت المدة التي حدّدتها لـ$name وما زال ينقصه ${_p.money(goal.remaining)}، فمدّد المدة أو زِد المبلغ الشهري.',
              'بلغ $name ${_p.percent(goal.ratio)} بعد انتهاء موعده. لا بأس، عدّل الخطة وتابع.',
            ]),
            detail: detail,
            priority: 70,
          ),
        );
        continue;
      }

      final needed = goal.remaining / math.max(0.25, monthsToDeadline);
      if (pace <= 0 || goal.remaining / pace > monthsToDeadline + 0.25) {
        results.add(
          SmartInsight(
            id: 'goal-behind-${goal.id}',
            tone: InsightTone.warning,
            icon: Icons.speed_rounded,
            title: _p.pick(['$name يحتاج إلى تسريع', 'وتيرة $name بطيئة']),
            body: _p.say(InsightTone.warning, [
              'لتحقيق $name في موعده تحتاج إلى قرابة ${_p.money(needed)} شهرياً.',
              'بوتيرتك الحالية لن يكتمل $name في موعده، فخصّص له ${_p.money(needed)} شهرياً.',
            ]),
            detail: '$detail\nالمطلوب شهرياً: ${_p.money(needed)}',
            priority: 68,
            action: InsightAction.manualSave,
          ),
        );
      } else {
        results.add(
          SmartInsight(
            id: 'goal-ontrack-${goal.id}',
            tone: InsightTone.positive,
            icon: Icons.track_changes_rounded,
            title: _p.pick(['$name على المسار', 'تقدّم جيد في $name']),
            body: _p.say(InsightTone.positive, [
              'وصلت إلى ${_p.percent(goal.ratio)} من $name، وبهذه الوتيرة ستحققه في موعده.',
              'يسير $name كما خطّطت (${_p.percent(goal.ratio)}).',
            ]),
            detail: detail,
            priority: 46,
          ),
        );
      }
    }
    return results;
  }

  // The first goal (two weeks old or more) with nothing saved for 30 days.
  SmartInsight? _stalledGoal() {
    for (final goal in facts.goals) {
      if (goal.ratio >= 1) continue;
      if (facts.today.difference(goal.createdAt).inDays < 14) continue;
      final last = facts.lastSavedFor(goal.id);
      if (last != null && facts.today.difference(last).inDays < 30) continue;
      final name = Ar.quote(goal.name);
      return SmartInsight(
        id: 'goal-stalled-${goal.id}',
        tone: InsightTone.tip,
        icon: Icons.pause_circle_outline_rounded,
        title: _p.pick(['$name متوقف', 'لم توفّر لـ$name مؤخراً']),
        body: _p.say(InsightTone.tip, [
          'مرّ أكثر من شهر دون إضافة إلى $name، وحتى مبلغ صغير يعيد الزخم.',
          '$name بانتظارك. جرّب تحويل مبلغ ثابت مع كل دخل.',
        ]),
        priority: 64,
        action: InsightAction.manualSave,
      );
    }
    return null;
  }

  // Net saving over 30 days as a share of income, against the 20% rule.
  SmartInsight? _savingsRate() {
    final income = facts.effectiveMonthlyIncome;
    if (income == null || income <= 0) return null;
    final rate = facts.savedLast30 / income;
    if (rate >= 0.2) {
      return SmartInsight(
        id: 'savings-rate',
        tone: InsightTone.positive,
        icon: Icons.savings_outlined,
        title: _p.pick([
          'نسبة توفير ممتازة',
          'توفّر ${_p.percent(rate)} من دخلك',
        ]),
        body: _p.say(InsightTone.positive, [
          'وفّرت ${_p.money(facts.savedLast30)} خلال آخر 30 يوماً، أي ${_p.percent(rate)} من دخلك، وهذا فوق نسبة ${_p.percent(0.2)} الموصى بها.',
          'نسبة توفيرك ${_p.percent(rate)}، وأنت تبني أماناً مالياً حقيقياً.',
        ]),
        priority: 60,
      );
    }
    if (rate < 0.05) {
      return SmartInsight(
        id: 'savings-rate',
        tone: InsightTone.tip,
        icon: Icons.savings_outlined,
        title: _p.pick([
          'التوفير منخفض هذا الشهر',
          'ابدأ بنسبة ${_p.percent(0.05)} فقط',
        ]),
        body: _p.say(InsightTone.tip, [
          'وفّرت ${_p.money(math.max(0, facts.savedLast30))} خلال آخر 30 يوماً. ابدأ بنسبة ${_p.percent(0.05)} من الدخل (${_p.money(income * 0.05)}) ثم زِدها تدريجياً.',
          'القاعدة الشائعة أن تخصّص ${_p.percent(0.2)} من الدخل للتوفير، وإن كان ذلك صعباً فابدأ بـ${_p.money(income * 0.05)} شهرياً.',
        ]),
        priority: 66,
        action: InsightAction.manualSave,
      );
    }
    return SmartInsight(
      id: 'savings-rate',
      tone: InsightTone.info,
      icon: Icons.savings_outlined,
      title: _p.pick(['نسبة توفيرك', 'أنت في منتصف الطريق']),
      body: _p.say(InsightTone.info, [
        'وفّرت ${_p.percent(rate)} من دخلك خلال آخر 30 يوماً، والوصول إلى ${_p.percent(0.2)} يعني ${_p.money(income * 0.2)} شهرياً.',
      ]),
      priority: 40,
    );
  }

  /// A realistic monthly amount: what is left after obligations and normal
  /// spending, kept below the 20% rule so it stays sustainable. Null when
  /// income is unknown or nothing is left.
  double? suggestedMonthlySaving() {
    final income = facts.effectiveMonthlyIncome;
    if (income == null || income <= 0) return null;
    final spare = income - facts.obligationsMonthly - facts.averageMonthlySpend;
    if (spare <= 0) return null;
    final amount = math.min(spare * 0.7, income * 0.2);
    if (amount <= 0) return null;
    // Round to a friendly figure.
    final step = amount >= 1000 ? 100.0 : (amount >= 100 ? 10.0 : 1.0);
    return (amount / step).floor() * step;
  }

  // A concrete monthly amount from [suggestedMonthlySaving].
  SmartInsight? _savingSuggestion() {
    final amount = suggestedMonthlySaving();
    final income = facts.effectiveMonthlyIncome;
    if (amount == null || income == null) return null;
    return SmartInsight(
      id: 'saving-suggestion',
      tone: InsightTone.tip,
      icon: Icons.lightbulb_outline_rounded,
      title: _p.pick([
        'اقتراح: وفّر ${_p.money(amount)} شهرياً',
        'مبلغ توفير واقعي لك',
        'كم يمكنك أن توفّر؟',
      ]),
      body: _p.say(InsightTone.tip, [
        'بعد الالتزامات ومتوسط صرفك، يمكنك توفير نحو ${_p.money(amount)} شهرياً دون ضغط على ميزانيتك.',
        'بحسب دخلك وصرفك المعتاد، يُعدّ ${_p.money(amount)} شهرياً مبلغاً مريحاً للتوفير، أي ${_p.money(amount * 12)} في السنة.',
        'جرّب تحويل ${_p.money(amount)} إلى التوفير فور وصول دخلك، قبل أن تبدأ بالصرف.',
      ]),
      detail:
          'الدخل الشهري: ${_p.money(income)}\n'
          'الالتزامات: ${_p.money(facts.obligationsMonthly)}\n'
          'متوسط الصرف: ${_p.money(facts.averageMonthlySpend)}',
      priority: 62,
      action: facts.goals.isEmpty
          ? InsightAction.createGoal
          : InsightAction.manualSave,
    );
  }

  // Two withdrawals from savings or more in 30 days.
  SmartInsight? _withdrawals() {
    final count = facts.withdrawalsLast30;
    if (count < 2) return null;
    final times = Ar.times.of(count);
    return SmartInsight(
      id: 'withdrawals',
      tone: InsightTone.warning,
      icon: Icons.output_rounded,
      title: _p.pick(['سحوبات متكررة من التوفير', 'سحبت من التوفير $times']),
      body: _p.say(InsightTone.warning, [
        'سحبت من التوفير $times خلال آخر 30 يوماً، والتوفير ينجح أكثر حين يبقى بعيداً عن الصرف اليومي.',
        'قد يعني السحب المتكرر أن الميزانية الشهرية ضيقة، فراجع أكبر تصنيفاتك قبل السحب القادم.',
      ]),
      priority: 72,
    );
  }

  // Praise for moving period leftovers to savings.
  SmartInsight? _leftoverHabit() {
    final count = facts.leftoverTransfers;
    if (count < 1) return null;
    return SmartInsight(
      id: 'leftover-habit',
      tone: InsightTone.positive,
      icon: Icons.move_down_rounded,
      title: _p.pick(['عادة ذكية', 'تنقل الفائض إلى التوفير']),
      body: _p.say(InsightTone.positive, [
        'نقلت باقي رصيدك إلى التوفير ${Ar.times.of(count)}، وهذه من أفضل العادات المالية.',
        'كل مرة تنقل فيها ما تبقّى إلى التوفير تبني رصيداً دون جهد إضافي.',
      ]),
      priority: 34,
    );
  }

  // Goals completed so far.
  SmartInsight? _completedGoals() {
    final count = facts.completedGoals;
    if (count < 1) return null;
    final counted = Ar.goals.of(count);
    return SmartInsight(
      id: 'completed-goals',
      tone: InsightTone.positive,
      icon: Icons.workspace_premium_outlined,
      title: _p.pick([
        count == 1 ? 'حققت هدفاً!' : 'حققت $counted',
        'إنجازاتك في التوفير',
      ]),
      body: _p.say(InsightTone.positive, [
        'أكملت $counted حتى الآن، وهذا دليل على قدرتك. فما الهدف التالي؟',
        'إنجاز الأهداف السابقة يعني أن خطتك تعمل، فارفع سقف الهدف القادم قليلاً.',
      ]),
      priority: 33,
      action: facts.goals.isEmpty ? InsightAction.createGoal : null,
    );
  }

  // Months of normal spending the savings cover; three is the target.
  SmartInsight? _emergencyFund() {
    final monthly = facts.averageMonthlySpend;
    if (monthly <= 0) return null;
    final months = facts.savingsBalance / monthly;
    final covered = months.toStringAsFixed(1);
    if (months >= 3) {
      return SmartInsight(
        id: 'emergency-fund',
        tone: InsightTone.positive,
        icon: Icons.shield_outlined,
        title: _p.pick([
          'صندوق طوارئ متين',
          'أمان يكفي ${Ar.months.of(months.floor())}',
        ]),
        body: _p.say(InsightTone.positive, [
          'يغطي توفيرك (${_p.money(facts.savingsBalance)}) صرفك المعتاد لمدة \u2066$covered\u2069 شهر تقريباً.',
        ]),
        priority: 38,
      );
    }
    return SmartInsight(
      id: 'emergency-fund',
      tone: InsightTone.tip,
      icon: Icons.shield_outlined,
      title: _p.pick(['ابنِ صندوق طوارئ', 'كم يغطي توفيرك؟']),
      body: _p.say(InsightTone.tip, [
        'يغطي توفيرك صرفك المعتاد لمدة \u2066$covered\u2069 شهر فقط، والحدّ الآمن ثلاثة أشهر، أي ${_p.money(monthly * 3)}.',
        'يحميك صندوق الطوارئ من المفاجآت، فاجعل هدفك الأول ${_p.money(monthly * 3)}، أي صرف ثلاثة أشهر.',
      ]),
      priority: 44,
      action: facts.goals.isEmpty
          ? InsightAction.createGoal
          : InsightAction.manualSave,
    );
  }

  // Three items or more still on the shopping list.
  SmartInsight? _shoppingList() {
    final count = facts.pendingShopping;
    if (count < 3) return null;
    final counted = Ar.items.of(count);
    return SmartInsight(
      id: 'shopping-list',
      tone: InsightTone.tip,
      icon: Icons.checklist_rounded,
      title: _p.pick(['$counted في قائمة المشتريات', 'قائمتك بانتظارك']),
      body: _p.say(InsightTone.tip, [
        'لديك $counted لم تشترِها بعد، فحدّد ميزانية للقائمة قبل الخروج للتسوق.',
        'التسوق من قائمة يقلّل الشراء العشوائي، فراجع العناصر واحذف غير الضروري منها.',
      ]),
      priority: 30,
      action: InsightAction.shoppingList,
    );
  }
}
