// ActiveListenableBuilder: hidden tabs skip rebuilds and catch up when shown.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/widgets/motion/active_listenable_builder.dart';

class _ProbeNotifier extends ValueNotifier<int> {
  _ProbeNotifier(super.value);
  bool get listening => hasListeners;
}

void main() {
  testWidgets('hidden tab skips data rebuilds and catches up on return', (
    tester,
  ) async {
    final source = _ProbeNotifier(0);
    final active = ValueNotifier<bool>(true);
    addTearDown(source.dispose);
    addTearDown(active.dispose);
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: active,
          child: ActiveListenableBuilder(
            listenable: source,
            builder: (_, _) {
              builds++;
              return Text('${source.value}');
            },
          ),
          builder: (_, enabled, child) =>
              TickerMode(enabled: enabled, child: child!),
        ),
      ),
    );
    source.value = 1;
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    active.value = false;
    await tester.pump();
    final hiddenBuilds = builds;
    source.value = 2;
    source.value = 3;
    await tester.pump();
    expect(builds, hiddenBuilds);
    active.value = true;
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(source.listening, isFalse);
  });

  testWidgets('replacement source is used after inactive state', (
    tester,
  ) async {
    final first = _ProbeNotifier(1);
    final second = _ProbeNotifier(2);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget view(Listenable source, bool active) => MaterialApp(
      home: TickerMode(
        enabled: active,
        child: ActiveListenableBuilder(
          listenable: source,
          builder: (_, _) => const Text('retained'),
        ),
      ),
    );
    await tester.pumpWidget(view(first, true));
    expect(first.listening, isTrue);
    await tester.pumpWidget(view(second, false));
    expect(first.listening, isFalse);
    expect(second.listening, isFalse);
    await tester.pumpWidget(view(second, true));
    expect(second.listening, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(second.listening, isFalse);
  });
}
