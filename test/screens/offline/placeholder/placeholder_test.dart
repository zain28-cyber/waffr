// Smoke test for the placeholder screen.

import 'package:waffr/screens/offline/placeholder/placeholder.dart';

import '../../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen(
    'PlaceholderScreen',
    () => const PlaceholderScreen(label: 'label'),
    withSampleData: false,
  );
}
