// Smoke tests for the profile tab and its streak card.

import 'package:flutter/material.dart';
import 'package:waffr/screens/offline/profile/profile_screen.dart';
import 'package:waffr/screens/offline/profile/streak_card.dart';

import '../../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen(
    'ProfileScreen',
    () => ProfileScreen(tabIndex: ValueNotifier<int>(3)),
  );
  smokeTestScreen(
    'StreakCard',
    () => Scaffold(
      body: StreakCard(count: 4, lastDay: DateTime.now(), replayToken: 0),
    ),
    screenType: StreakCard,
    withSampleData: false,
  );
}
