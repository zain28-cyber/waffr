// Smoke tests for the settings screen and every screen it opens.

import 'package:flutter/material.dart';
import 'package:waffr/screens/offline/settings/account_screen.dart';
import 'package:waffr/screens/offline/settings/ai_permissions_screen.dart';
import 'package:waffr/screens/offline/settings/change_password_screen.dart';
import 'package:waffr/screens/offline/settings/help_screen.dart';
import 'package:waffr/screens/offline/settings/privacy_info_screen.dart';
import 'package:waffr/screens/offline/settings/privacy_security_screen.dart';
import 'package:waffr/screens/offline/settings/settings_screen.dart';

import '../../../helpers/widget_harness.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    smokeTestScreen(
      'SettingsScreen (${mode.name} notifier)',
      () => SettingsScreen(
        themeNotifier: ValueNotifier(mode),
        onThemeChanged: () {},
        appFlowController: null,
      ),
    );
  }
  smokeTestScreen('PrivacySecurityScreen', () => const PrivacySecurityScreen());
  smokeTestScreen('AccountScreen', () => const AccountScreen());
  smokeTestScreen('AIPermissionsScreen', () => const AIPermissionsScreen());
  smokeTestScreen('ChangePasswordScreen', () => const ChangePasswordScreen());
  smokeTestScreen('HelpScreen', () => const HelpScreen());
  smokeTestScreen('PrivacyInfoScreen', () => const PrivacyInfoScreen());
}
