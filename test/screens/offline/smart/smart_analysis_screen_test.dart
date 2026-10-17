// Smoke tests for the smart analysis screen in every insight scope.

import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/screens/offline/smart/smart_analysis_screen.dart';

import '../../../helpers/widget_harness.dart';

void main() {
  for (final scope in InsightScope.values) {
    smokeTestScreen(
      'SmartAnalysisScreen (${scope.name})',
      () => SmartAnalysisScreen(scope: scope),
      settle: const Duration(seconds: 8),
    );
  }
}
