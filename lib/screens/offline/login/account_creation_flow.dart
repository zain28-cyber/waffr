// Signup flow that pairs the user-info step with the credentials step on a
// single route.

import 'package:flutter/material.dart';
import 'package:waffr/data/models/registration_profile.dart';
import 'package:waffr/screens/offline/login/register_screen.dart';
import 'package:waffr/screens/offline/user_info/user_info_screen.dart';

/// Two-step signup on one route: profile ([UserInfoScreen]), then
/// credentials ([RegisterScreen]). Pushed from [LoginScreen]'s register link.
class AccountCreationFlow extends StatefulWidget {
  /// Runs after the account is created; passed through to [RegisterScreen].
  final Future<void> Function() onCompleted;

  /// Pop back to the opener once registration succeeds.
  final bool popOnSuccess;

  /// Creates a [AccountCreationFlow].
  const AccountCreationFlow({
    super.key,
    required this.onCompleted,
    this.popOnSuccess = false,
  });

  @override
  State<AccountCreationFlow> createState() => _AccountCreationFlowState();
}

/// State of [AccountCreationFlow]. Keeps the profile from step 0 and which
/// step is showing.
class _AccountCreationFlowState extends State<AccountCreationFlow> {
  /// Profile collected on the user-info step; null until it is submitted.
  RegistrationProfile? _profile;

  /// 0 = user info, 1 = email and password.
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return PopScope(
      // On step 1, system back returns to user info instead of leaving.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _step == 0) return;
        setState(() => _step = 0);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Step 0 stays mounted (offstage) so its fields survive a trip back.
          Offstage(
            offstage: _step != 0,
            child: UserInfoScreen(
              onBack: () => Navigator.of(context).pop(),
              onContinue: (value) {
                setState(() {
                  _profile = value;
                  _step = 1;
                });
              },
            ),
          ),
          if (_step == 1 && profile != null)
            RegisterScreen(
              profile: profile,
              onBack: () => setState(() => _step = 0),
              onCompleted: widget.onCompleted,
              popOnSuccess: widget.popOnSuccess,
            ),
        ],
      ),
    );
  }
}
