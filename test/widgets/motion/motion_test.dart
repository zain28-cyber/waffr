// Motion basics: reduced-motion page transitions and reveals that keep their
// child alive after the entrance.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/widgets/motion/motion.dart';

void main() {
  testWidgets('reduced-motion page transition returns the page as is', (
    tester,
  ) async {
    const builder = ReducedMotionPageTransitionsBuilder(
      ZoomPageTransitionsBuilder(),
    );
    const page = Text('page');
    final route = MaterialPageRoute<void>(builder: (_) => page);
    Widget? reduced;
    Widget? animated;

    Widget probe({required bool disable, required ValueSetter<Widget> out}) {
      return MediaQuery(
        data: MediaQueryData(disableAnimations: disable),
        child: Builder(
          builder: (context) {
            out(
              builder.buildTransitions(
                route,
                context,
                kAlwaysCompleteAnimation,
                kAlwaysDismissedAnimation,
                page,
              ),
            );
            return const SizedBox();
          },
        ),
      );
    }

    await tester.pumpWidget(probe(disable: true, out: (w) => reduced = w));
    expect(identical(reduced, page), isTrue);

    await tester.pumpWidget(probe(disable: false, out: (w) => animated = w));
    expect(identical(animated, page), isFalse);
    route.dispose();
  });

  testWidgets('Reveal keeps its child alive when the entrance ends', (
    tester,
  ) async {
    var inits = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Reveal(child: _Counted(onInit: () => inits++)),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(inits, 1, reason: 'the child must not be rebuilt from scratch');
  });

  testWidgets('RevealClip keeps its child alive when it completes', (
    tester,
  ) async {
    var inits = 0;
    Widget at(double fraction) => Directionality(
      textDirection: TextDirection.ltr,
      child: RevealClip(
        fraction: fraction,
        child: _Counted(onInit: () => inits++),
      ),
    );
    await tester.pumpWidget(at(0.5));
    await tester.pumpWidget(at(1));
    expect(inits, 1);
  });
}

class _Counted extends StatefulWidget {
  final VoidCallback onInit;

  const _Counted({required this.onInit});

  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}
