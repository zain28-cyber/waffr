// The parts of a report around the cards: the closing tip, the headline
// and the short summary.

import 'package:flutter/material.dart';
import 'package:waffr/core/insights/smart/arabic_text.dart';
import 'package:waffr/core/insights/smart/insight_phrasing.dart';
import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/core/insights/smart/profile_insights.dart';
import 'package:waffr/core/insights/smart/report_insights.dart';

/// Writes the tip, headline and summary of a report.
class InsightSummary {
  /// Text over [facts], worded through the run's shared phrasing.
  InsightSummary(this.facts, this._p);

  /// The numbers of this run.
  final SmartFacts facts;

  final InsightPhrasing _p;

  static const List<String> _generalTips = [
    'ادفع لنفسك أولاً: حوّل مبلغ التوفير فور وصول الدخل.',
    'قاعدة الـ24 ساعة: انتظر يوماً كاملاً قبل أي شراء غير ضروري.',
    'راجع اشتراكاتك الشهرية مرة كل ثلاثة أشهر، وألغِ ما لا تستخدمه.',
    'حدّد سقفاً أسبوعياً للمطاعم بدلاً من سقف شهري، فهو أسهل في المتابعة.',
    'سجّل المصروف لحظة دفعه، فالتأجيل يعني النسيان.',
    'قاعدة 50/30/20: نصف الدخل للضروريات، وثلاثة أعشاره للرغبات، وخُمسه للتوفير.',
    'التسوق بقائمة وبعد تناول الطعام يقلّل الشراء العشوائي بوضوح.',
    'امنح هدف التوفير اسماً واضحاً، فالأهداف المسمّاة تتحقق أسرع.',
    'المبالغ الصغيرة اليومية تصنع فرقاً كبيراً في نهاية السنة.',
    'قبل أي شراء كبير، احسب عدد أيام العمل التي يكلّفك إياها.',
    'خصّص يوماً في الأسبوع بلا صرف، وراقب أثره في الشهر.',
    'ابدأ صندوق طوارئ يغطي ثلاثة أشهر من مصاريفك الأساسية.',
    'قارن الأسعار قبل الشراء، خصوصاً في المشتريات المتكررة.',
    'كافئ نفسك عند تحقيق هدف، لكن بمبلغ محدد مسبقاً.',
    'راجع تقريرك الأسبوعي كل جمعة، فالمراجعة الدورية تمنع المفاجآت.',
    'العروض ليست توفيراً إن لم تكن بحاجة إلى الشيء أصلاً.',
  ];

  /// A general money tip, or one that fits [scope].
  SmartInsight tip(InsightScope scope) {
    final scoped = switch (scope) {
      InsightScope.reports => [
        'تقسيم الميزانية على الأسابيع يجعل التحكم في الصرف أسهل من متابعة الشهر كاملاً.',
        'راجع أكبر ثلاثة مصاريف كل أسبوع واسأل نفسك: هل كانت ضرورية؟',
      ],
      InsightScope.savings => [
        'التوفير التلقائي مع كل دخل أسهل من التوفير مما يتبقّى آخر الشهر.',
        'قسّم الهدف الكبير إلى مراحل شهرية صغيرة.',
      ],
      InsightScope.profile => ['أفضل وقت لمراجعة وضعك المالي بداية كل شهر.'],
    };
    return SmartInsight(
      id: 'tip',
      tone: InsightTone.tip,
      icon: Icons.tips_and_updates_outlined,
      title: _p.pick([
        'نصيحة سريعة',
        'فكرة لك',
        'هل تعلم؟',
        'من خبرة المدّخرين',
      ]),
      body: _p.pick([..._generalTips, ...scoped]),
      priority: 0,
    );
  }

  /// One line above the cards: health for the profile, else what the
  /// warnings and positives add up to.
  String headline(InsightScope scope, List<SmartInsight> insights, int? score) {
    final warnings = insights
        .where((item) => item.tone == InsightTone.warning)
        .length;
    final positives = insights
        .where((item) => item.tone == InsightTone.positive)
        .length;

    if (scope == InsightScope.profile && score != null) {
      final label = healthLabel(score);
      return _p.pick([
        'صحتك المالية $label، وإليك الصورة الكاملة.',
        'مؤشرك \u2066$score/100\u2069، وهذا ما لاحظته عنك.',
        'نظرة شاملة على وضعك: $label.',
        'جمعت لك أهم ما في مصاريفك وتوفيرك وعاداتك.',
      ]);
    }
    if (!facts.hasExpenses && scope == InsightScope.reports) {
      return _p.pick([
        'لنبدأ معاً: سجّل مصاريفك لأحلّلها لك.',
        'التحليل جاهز حالما تبدأ بالتسجيل.',
      ]);
    }
    if (warnings >= 2) {
      return _p.pick([
        warnings == 2
            ? 'هناك نقطتان تحتاجان إلى انتباهك.'
            : 'هناك $warnings نقاط تحتاج إلى انتباهك.',
        'لاحظت أموراً تستحق التوقف عندها.',
        'وضعك جيد، لكن انتبه لهذه النقاط.',
        'إليك ما يحتاج إلى متابعة أدق.',
      ]);
    }
    if (warnings == 1) {
      return _p.pick([
        'نقطة واحدة تحتاج إلى انتباهك، والباقي جيد.',
        'أغلب المؤشرات جيدة مع ملاحظة مهمة.',
        'الصورة إيجابية في معظمها، باستثناء أمر واحد.',
      ]);
    }
    if (positives >= 2) {
      return _p.pick([
        'أداء رائع! إليك ما يسير على ما يرام.',
        'أخبار جيدة: أنت تتحسّن.',
        'استمرّ، فالمؤشرات في صالحك.',
      ]);
    }
    return switch (scope) {
      InsightScope.savings => _p.pick([
        'هذه قراءتي لتوفيرك وأهدافك.',
        'إليك وضع توفيرك واقتراحاتي.',
      ]),
      _ => _p.pick(['هذه قراءتي لمصاريفك.', 'إليك أهم ما لاحظته في صرفك.']),
    };
  }

  /// The short summary under the headline.
  String summary(InsightScope scope) {
    final parts = <String>[];
    switch (scope) {
      case InsightScope.reports:
        if (facts.monthSpent > 0) {
          parts.add(
            _p.pick([
              'صرفت هذا الشهر ${_p.money(facts.monthSpent)} بمعدل ${_p.money(facts.dailyAverageThisMonth)} يومياً.',
              'حتى اليوم ${facts.dayOfMonth} من الشهر بلغ صرفك ${_p.money(facts.monthSpent)}.',
              'إجمالي صرفك منذ بداية الشهر ${_p.money(facts.monthSpent)}.',
            ]),
          );
        }
        final top = largestCategory(facts.monthCategories);
        if (top != null) {
          final name = Ar.category(top.key);
          parts.add(
            _p.pick([
              'أكبر تصنيف هو $name.',
              'ذهب معظم الصرف إلى $name.',
              'يتصدّر $name قائمة مصاريفك.',
            ]),
          );
        }
      case InsightScope.savings:
        parts.add(
          _p.pick([
            'رصيد توفيرك ${_p.money(facts.savingsBalance)}.',
            'لديك ${_p.money(facts.savingsBalance)} في التوفير.',
          ]),
        );
        if (facts.goals.isNotEmpty) {
          parts.add('لديك ${Ar.activeGoals.of(facts.goals.length)}.');
        }
      case InsightScope.profile:
        parts.add(
          _p.pick([
            'جمعت هنا أهم ما في مصاريفك وتوفيرك وعاداتك.',
            'قراءة شاملة مبنية على كل ما سجّلته.',
            'هذه خلاصة ما تقوله أرقامك.',
          ]),
        );
    }
    return parts.join(' ');
  }
}
