// Smoke tests for the smart analysis widgets: icon, glow, spark and the
// entry button in each style and scope.

import 'package:flutter/material.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/widgets/smart/smart_analysis_button.dart';
import 'package:waffr/widgets/smart/smart_glow.dart';

import '../../helpers/widget_harness.dart';

void main() {
  smokeTestWidget(
    SmartGradientIcon,
    () => const SmartGradientIcon(Icons.auto_graph_rounded),
  );
  smokeTestWidget(
    SmartGlowBackground,
    () => const SizedBox(height: 200, child: SmartGlowBackground(intensity: 1)),
    find: SmartGlowBackground,
  );
  smokeTestWidget(SmartSpark, () => const SmartSpark(spinning: true));
  for (final style in SmartButtonStyle.values) {
    for (final scope in InsightScope.values) {
      smokeTestWidget(
        SmartAnalysisButton,
        () => SmartAnalysisButton(scope: scope, style: style),
        name: 'SmartAnalysisButton (${style.name}, ${scope.name})',
      );
    }
  }
}
