// Wallet backdrop motion: animation runs only while the profile tab is
// active and motion is allowed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/screens/offline/profile/wallet_backdrop.dart';

void main() {
  testWidgets(
    'wallet updates all expressions and stops motion when hidden or reduced',
    (tester) async {
      Widget view(
        HealthBand? band, {
        bool reduced = false,
        bool active = true,
      }) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: active,
            child: SizedBox(
              width: 400,
              height: 800,
              child: WalletBackdrop(
                page: const Size(400, 800),
                band: band,
                active: active,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(view(HealthBand.excellent));
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/brand/waffr_logo_backdrop.png'),
          tester.element(find.byType(WalletBackdrop)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(view(HealthBand.good, active: false));
      expect(tester.binding.transientCallbackCount, 0);
      for (final band in HealthBand.values) {
        await tester.pumpWidget(view(band, reduced: true));
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(view(null));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
