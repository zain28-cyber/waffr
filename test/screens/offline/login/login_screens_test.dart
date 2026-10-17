// Smoke tests for sign-in, registration and password reset screens.

import 'package:waffr/data/models/country.dart';
import 'package:waffr/data/models/registration_profile.dart';
import 'package:waffr/screens/offline/login/account_creation_flow.dart';
import 'package:waffr/screens/offline/login/forgot_password_screen.dart';
import 'package:waffr/screens/offline/login/login_screen.dart';
import 'package:waffr/screens/offline/login/register_screen.dart';

import '../../../helpers/widget_harness.dart';

void main() {
  smokeTestScreen(
    'LoginScreen',
    () => LoginScreen(onCompleted: () async {}),
    withSampleData: false,
  );
  smokeTestScreen(
    'AccountCreationFlow',
    () => AccountCreationFlow(onCompleted: () async {}),
    withSampleData: false,
  );
  smokeTestScreen(
    'RegisterScreen',
    () => RegisterScreen(
      profile: RegistrationProfile(
        name: 'name',
        birthDate: DateTime(1995, 4, 12),
        country: Countries.all.first.arabicName,
      ),
      onCompleted: () async {},
    ),
    withSampleData: false,
  );
  smokeTestScreen(
    'ForgotPasswordScreen',
    () => const ForgotPasswordScreen(),
    withSampleData: false,
  );
}
