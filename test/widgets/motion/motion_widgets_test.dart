// Smoke tests for the shared motion widgets at rest and mid-animation.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/motion/motion.dart';

import '../../helpers/widget_harness.dart';

void main() {
  smokeTestWidget(Reveal, () => const Reveal(index: 2, child: Text('row')));
  smokeTestWidget(
    RollingMoney,
    () => const RollingMoney(value: 125000, style: TextStyle(fontSize: 30)),
  );
  smokeTestWidget(
    RollingText,
    () => const RollingText(
      from: '1,000',
      to: '12,500',
      progress: 0.4,
      style: TextStyle(fontSize: 24),
    ),
  );
  smokeTestWidget(
    AnimatedRatio,
    () => AnimatedRatio(
      value: 0.6,
      builder: (context, value) => LinearProgressIndicator(value: value),
    ),
  );
  smokeTestWidget(
    RevealClip,
    () => const RevealClip(fraction: 0.5, child: Text('half')),
  );
}
