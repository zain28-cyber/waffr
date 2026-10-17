// Motion widget lifecycles: reveals, rolling money and text, glows and the
// streak number cancel timers and honor reduced motion and text scaling.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/widgets/motion/motion.dart';
import 'package:waffr/widgets/smart/smart_glow.dart';
import 'package:waffr/screens/offline/profile/streak_card.dart';
import 'package:waffr/widgets/brand/streak_celebration.dart';

Widget _view(
  Widget child, {
  bool reduced = false,
  bool active = true,
  double scale = 1,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduced,
      textScaler: TextScaler.linear(scale),
    ),
    child: TickerMode(
      enabled: active,
      child: Center(child: child),
    ),
  ),
);

void main() {
  testWidgets(
    'streak overlay finishes once if reduced motion is enabled mid-animation',
    (tester) async {
      var finished = 0;
      final overlay = StreakCelebrationOverlay(
        from: 1,
        to: 2,
        onFinished: () => finished++,
      );
      await tester.pumpWidget(_view(overlay));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(_view(overlay, reduced: true));
      await tester.pumpWidget(_view(overlay, reduced: true));
      expect(finished, 1);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion cancels a delayed reveal without restarting it', (
    tester,
  ) async {
    const reveal = Reveal(index: 8, child: Text('visible'));
    await tester.pumpWidget(_view(reveal));
    await tester.pumpWidget(_view(reveal, reduced: true));
    expect(
      find.descendant(of: find.byType(Reveal), matching: find.byType(Opacity)),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_view(reveal));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('removing a staggered reveal cancels its pending timer', (
    tester,
  ) async {
    await tester.pumpWidget(_view(const Reveal(index: 8, child: Text('gone'))));
    await tester.pumpWidget(const SizedBox());
    // The test binding rejects any pending timer at the end of this test.
    expect(tester.takeException(), isNull);
  });

  testWidgets('money retargets from the visually dominant digits', (
    tester,
  ) async {
    Widget money(num value) =>
        _view(RollingMoney(value: value, style: const TextStyle(fontSize: 20)));
    await tester.pumpWidget(money(10));
    await tester.pumpWidget(money(20));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(money(30));
    final rolling = tester.widget<RollingText>(find.byType(RollingText));
    expect(rolling.from, '20');
    expect(rolling.to, '30');
    await tester.pumpWidget(
      _view(
        const RollingMoney(value: 30, style: TextStyle(fontSize: 20)),
        reduced: true,
      ),
    );
    expect(find.byType(RollingText), findsNothing);
    expect(find.text('30'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('rolling separators follow accessibility text scaling', (
    tester,
  ) async {
    const rolling = RollingText(
      from: '999',
      to: '1,000',
      progress: 0.6,
      style: TextStyle(fontSize: 20),
    );
    await tester.pumpWidget(_view(rolling));
    final small = tester.getSize(find.byType(RollingText));
    await tester.pumpWidget(_view(rolling, scale: 2));
    final large = tester.getSize(find.byType(RollingText));
    expect(large.width, closeTo(small.width * 2, 0.1));
    expect(large.height, closeTo(small.height * 2, 0.1));
  });

  testWidgets(
    'spark settles across rebuilds and resumes after a rapid toggle',
    (tester) async {
      await tester.pumpWidget(_view(const SmartSpark(spinning: true)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_view(const SmartSpark()));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpWidget(_view(const SmartSpark(size: 30)));
      }
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(_view(const SmartSpark(spinning: true)));
      await tester.pumpWidget(_view(const SmartSpark()));
      await tester.pumpWidget(_view(const SmartSpark(spinning: true)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(
        _view(const SmartSpark(spinning: true), reduced: true),
      );
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hidden or transparent glow does not keep scheduling frames', (
    tester,
  ) async {
    Widget glow(double intensity, {bool active = true}) => _view(
      SizedBox(
        width: 200,
        height: 200,
        child: SmartGlowBackground(intensity: intensity),
      ),
      active: active,
    );
    await tester.pumpWidget(glow(0));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(glow(1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(glow(1, active: false));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(glow(0));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('streak shows the final count immediately with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _view(
        const StreakCard(count: 12, lastDay: null, replayToken: 0),
        reduced: true,
      ),
    );
    expect(find.text('12'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(
      _view(
        const StreakCard(count: 15, lastDay: null, replayToken: 1),
        reduced: true,
      ),
    );
    expect(find.text('15'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
