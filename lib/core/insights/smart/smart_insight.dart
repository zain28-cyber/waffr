// What the smart analysis produces: a headline, a short summary, and a
// ranked list of insights for one area of the app.

import 'package:flutter/material.dart';

/// Which screen asked; each scope looks at a different slice of the data.
enum InsightScope {
  /// Spending: trends, categories, pace and bills.
  reports,

  /// Savings goals and habits.
  savings,

  /// The whole picture, with the health score.
  profile,
}

/// Arabic label and icon of each [InsightScope].
extension InsightScopeLabel on InsightScope {
  /// Arabic name shown in the analysis screen.
  String get label => switch (this) {
    InsightScope.reports => 'المصاريف',
    InsightScope.savings => 'التوفير',
    InsightScope.profile => 'نظرة شاملة',
  };

  /// Icon shown beside [label].
  IconData get icon => switch (this) {
    InsightScope.reports => Icons.bar_chart_rounded,
    InsightScope.savings => Icons.savings_outlined,
    InsightScope.profile => Icons.person_outline_rounded,
  };
}

/// How an insight reads, which sets its color and closing remark.
enum InsightTone {
  /// Something to watch or fix.
  warning,

  /// Good news.
  positive,

  /// A suggestion.
  tip,

  /// A neutral fact.
  info,
}

/// The four bands of the 0-100 health score. The analysis names them and
/// the wallet behind the profile smiles by them.
enum HealthBand {
  /// 80 and above.
  excellent,

  /// 65 to 79.
  good,

  /// 45 to 64.
  fair,

  /// Below 45.
  low;

  /// The band [score] falls in.
  static HealthBand of(int score) {
    if (score >= 80) return excellent;
    if (score >= 65) return good;
    if (score >= 45) return fair;
    return low;
  }
}

/// Something the user can do straight from an insight card.
enum InsightAction {
  /// Open the add-expense sheet.
  addExpense,

  /// Open the add-income sheet.
  addIncome,

  /// Open the create-goal sheet.
  createGoal,

  /// Open the manual-save sheet.
  manualSave,

  /// Open the recurring bills sheet.
  obligations,

  /// Open the shopping list.
  shoppingList,

  /// Open the expense history.
  expenseHistory,
}

/// Arabic button text of each [InsightAction].
extension InsightActionLabel on InsightAction {
  /// Text of the card's action button.
  String get label => switch (this) {
    InsightAction.addExpense => 'سجّل مصروف',
    InsightAction.addIncome => 'أضف دخل',
    InsightAction.createGoal => 'أنشئ هدف',
    InsightAction.manualSave => 'وفّر الآن',
    InsightAction.obligations => 'افتح الالتزامات',
    InsightAction.shoppingList => 'قائمة المشتريات',
    InsightAction.expenseHistory => 'سجل المصروفات',
  };
}

/// One insight card.
class SmartInsight {
  /// Stable per rule, so the screen can key cards and tests can find them.
  final String id;

  /// How the card reads (color, closing remark).
  final InsightTone tone;

  /// Icon at the start of the card.
  final IconData icon;

  /// Card title.
  final String title;

  /// Card body.
  final String body;

  /// The numbers behind the insight, shown when the card is expanded.
  final String? detail;

  /// Higher shows first.
  final int priority;

  /// Optional button that acts on the insight.
  final InsightAction? action;

  /// An insight card.
  const SmartInsight({
    required this.id,
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
    this.detail,
    this.priority = 50,
    this.action,
  });
}

/// The result of one analysis run for one scope.
class SmartReport {
  /// The scope that was analyzed.
  final InsightScope scope;

  /// One line above the cards.
  final String headline;

  /// Short summary under the headline.
  final String summary;

  /// Ranked cards, ending with a tip.
  final List<SmartInsight> insights;

  /// 0-100 financial health, profile scope only.
  final int? healthScore;

  /// A finished report.
  const SmartReport({
    required this.scope,
    required this.headline,
    required this.summary,
    required this.insights,
    this.healthScore,
  });
}
