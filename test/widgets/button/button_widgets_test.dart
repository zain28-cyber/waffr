// Smoke tests for the shared buttons, enabled, disabled and busy.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/widgets/button/app_primary_button.dart';
import 'package:waffr/widgets/button/glass_button.dart';

import '../../helpers/widget_harness.dart';

void main() {
  smokeTestWidget(
    AppPrimaryButton,
    () => AppPrimaryButton(
      label: 'save',
      onTap: () {},
      icon: Icons.check_rounded,
    ),
  );
  smokeTestWidget(
    AppPrimaryButton,
    () => AppPrimaryButton(label: 'save', onTap: () {}, enabled: false),
    name: 'AppPrimaryButton (disabled)',
  );
  smokeTestWidget(
    AppPrimaryButton,
    () => AppPrimaryButton(label: 'save', onTap: () {}, busy: true),
    name: 'AppPrimaryButton (busy)',
  );
  smokeTestWidget(
    GlassButton,
    () => GlassButton(onTap: () {}, child: const Text('tap')),
    interact: (tester) => tester.tap(find.byType(GlassButton)),
  );
  smokeTestWidget(
    GlassIconButton,
    () => GlassIconButton(
      icon: Icons.settings_rounded,
      label: 'settings',
      onPressed: () {},
      showDot: true,
    ),
  );
}
