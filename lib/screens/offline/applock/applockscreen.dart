// App-lock screen: asks for device authentication before the app opens.

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:waffr/widgets/button/app_primary_button.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Blocks the app until device auth (biometrics or PIN) succeeds. Shown by
/// `main.dart` over the hidden shell while the app lock is on.
class LockScreen extends StatefulWidget {
  /// Called once device auth succeeds (or the device has no auth support).
  final VoidCallback onAuthenticated;

  /// Creates a [LockScreen].
  const LockScreen({super.key, required this.onAuthenticated});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

/// State of [LockScreen]. Prompts automatically after the first frame and
/// again on each tap of the unlock button.
class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();

  /// A system prompt is open (or just closed); drops repeat taps and shows
  /// the button's busy state.
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  /// Prompts local_auth; unsupported devices skip straight through.
  Future<void> _authenticate() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final supported = await _auth.isDeviceSupported();

      if (!supported) {
        widget.onAuthenticated();
        return;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: '.',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (authenticated && mounted) {
        widget.onAuthenticated();
      }
    } on LocalAuthException catch (_) {
      // User cancelled or biometrics failed — stay locked.
    } catch (_) {
      // Unexpected auth error — stay locked.
    } finally {
      if (mounted) {
        // Brief pause so Android can dismiss the system auth UI first.
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final bg = palette.background;

    final textPrimary = palette.textPrimary;

    final accent = palette.accent;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          // Lock icon, title, hint, then the unlock button.
          children: [
            Icon(Icons.lock_rounded, size: 70, color: accent),

            const SizedBox(height: 25),

            Text(
              'مقفل',
              style: TextStyle(
                color: textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'افتح القفل للدخول إلى التطبيق',
              style: TextStyle(
                color: textPrimary.withValues(alpha: 0.6),
                fontSize: 14,
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: 200,
              child: AppPrimaryButton(
                label: 'فتح القفل',
                icon: Icons.fingerprint,
                busy: _loading,
                onTap: _authenticate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
