// Turns SmartFacts into a SmartReport. Everything runs on the device.
//
// Each rule checks one pattern in the numbers and, when it applies, writes
// an insight. Titles and sentences come in several phrasings, and bodies
// may gain an opening phrase and a closing remark, so the seed changes the
// wording each time while the findings stay the same.
//
// The rules live in report_insights.dart, savings_insights.dart and
// profile_insights.dart; the wording helpers in insight_phrasing.dart; the
// headline, summary and closing tip in insight_summary.dart.

import 'dart:math' as math;

import 'package:waffr/core/insights/smart/insight_phrasing.dart';
import 'package:waffr/core/insights/smart/insight_summary.dart';
import 'package:waffr/core/insights/smart/profile_insights.dart';
import 'package:waffr/core/insights/smart/report_insights.dart';
import 'package:waffr/core/insights/smart/savings_insights.dart';
import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';

/// Runs the insight rules for one scope and assembles the report.
///
/// All rule groups share one [InsightPhrasing] and one random source, and
/// are called in a fixed order, so the same seed gives the same report.
class InsightEngine {
  /// The numbers to analyze.
  final SmartFacts facts;

  final InsightPhrasing _phrasing;

  /// An engine over [facts]; a fixed [seed] fixes the wording (tests).
  InsightEngine(this.facts, {int? seed})
    : _phrasing = InsightPhrasing(facts.currencySymbol, math.Random(seed));

  // Most cards a scope shows before the closing tip.
  static const Map<InsightScope, int> _limits = {
    InsightScope.reports: 7,
    InsightScope.savings: 7,
    InsightScope.profile: 8,
  };

  /// The headline, summary and ranked insight cards for [scope].
  SmartReport analyze(InsightScope scope) {
    final found = switch (scope) {
      InsightScope.reports => ReportInsights(facts, _phrasing).all(),
      InsightScope.savings => SavingsInsights(facts, _phrasing).all(),
      InsightScope.profile => ProfileInsights(facts, _phrasing).all(),
    };

    // The cut is by priority alone so the findings stay the same; inside
    // it, near-equal priorities trade places between runs for variety.
    found.sort((a, b) => b.priority.compareTo(a.priority));
    final limited = found.take(_limits[scope]!).toList();
    final jitter = {for (final item in limited) item.id: _phrasing.nextInt(8)};
    limited.sort(
      (a, b) =>
          (b.priority + jitter[b.id]!).compareTo(a.priority + jitter[a.id]!),
    );

    // A tip always closes the list; the profile also carries the score.
    final text = InsightSummary(facts, _phrasing);
    limited.add(text.tip(scope));
    final score = scope == InsightScope.profile ? healthScore() : null;
    return SmartReport(
      scope: scope,
      headline: text.headline(scope, limited, score),
      summary: text.summary(scope),
      insights: limited,
      healthScore: score,
    );
  }

  /// Weighted 0-100 financial health score (see [ProfileInsights]).
  int healthScore() => ProfileInsights(facts, _phrasing).healthScore();

  /// A realistic monthly saving amount, or null (see [SavingsInsights]).
  double? suggestedMonthlySaving() =>
      SavingsInsights(facts, _phrasing).suggestedMonthlySaving();
}
