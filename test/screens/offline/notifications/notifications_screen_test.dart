// Smoke tests for the notifications screen.

import 'package:waffr/screens/offline/notifications/notifications_screen.dart';

import '../../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen('NotificationsScreen', () => const NotificationsScreen());
}
