// Streak celebration overlay: finishes once, can be skipped, and is skipped
// entirely under reduced motion.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/theme/app_theme.dart';
import 'package:waffr/widgets/brand/streak_celebration.dart';

void main() {
  Widget overlay(VoidCallback onFinished, {bool reduced = false}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: StreakCelebrationOverlay(
            from: 2,
            to: 3,
            onFinished: onFinished,
          ),
        ),
      ),
    );
  }

  testWidgets('finishes once when left alone', (tester) async {
    var finished = 0;
    await tester.pumpWidget(overlay(() => finished++));
    await tester.pump(const Duration(seconds: 4));
    expect(finished, 1);
  });

  testWidgets('a tap to skip still finishes, so the overlay never stays '
      'over the app blocking touches', (tester) async {
    var finished = 0;
    await tester.pumpWidget(overlay(() => finished++));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.byType(StreakCelebrationOverlay));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finished, 1);
  });

  testWidgets('reduced motion skips the sequence', (tester) async {
    var finished = 0;
    await tester.pumpWidget(overlay(() => finished++, reduced: true));
    await tester.pump();
    expect(finished, 1);
  });
}
