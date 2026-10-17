// smart_insight value types: health band cut-offs, scope and action labels,
// and the SmartInsight defaults.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';

void main() {
  test('health bands', () {
    expect(HealthBand.of(100), HealthBand.excellent);
    expect(HealthBand.of(80), HealthBand.excellent);
    expect(HealthBand.of(79), HealthBand.good);
    expect(HealthBand.of(65), HealthBand.good);
    expect(HealthBand.of(64), HealthBand.fair);
    expect(HealthBand.of(45), HealthBand.fair);
    expect(HealthBand.of(44), HealthBand.low);
    expect(HealthBand.of(-5), HealthBand.low);
  });

  test('every scope and action has a label', () {
    expect(InsightScope.values.map((s) => s.label).toSet(), hasLength(3));
    expect(InsightScope.reports.icon, Icons.bar_chart_rounded);
    expect(
      InsightAction.values.map((a) => a.label).toSet(),
      hasLength(InsightAction.values.length),
    );
    expect(InsightAction.addExpense.label, 'سجّل مصروف');
  });

  test('insight defaults', () {
    const insight = SmartInsight(
      id: 'x',
      tone: InsightTone.info,
      icon: Icons.info,
      title: 't',
      body: 'b',
    );
    expect(insight.priority, 50);
    expect(insight.detail, isNull);
    expect(insight.action, isNull);
  });
}
