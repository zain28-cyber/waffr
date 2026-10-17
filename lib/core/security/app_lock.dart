// Biometric / device-credential app lock toggle backed by SharedPreferences.

import 'package:local_auth/local_auth.dart';
import 'package:waffr/core/prefs/app_prefs.dart';

/// What happened when the user flipped the app-lock switch.
enum AppLockToggleResult {
  /// The device confirmed the user and the lock is on.
  enabled,

  /// The lock is off.
  disabled,

  /// The device has no biometrics or screen lock to use.
  unsupported,

  /// The user cancelled or failed the confirmation.
  cancelled,
}

/// Enables or disables requiring authentication when the app opens.
class AppLock {
  AppLock._();

  /// Prefs key of the on/off flag.
  static const prefsKey = 'app_lock';

  /// True when the app asks for authentication on open.
  static Future<bool> isEnabled() async {
    final prefs = await AppPrefs.instance;
    return prefs.getBool(prefsKey) ?? false;
  }

  /// Turning on prompts the OS authenticator first; turning off just
  /// clears the flag. [onEnabled] / [onDisabled] run after a change.
  static Future<AppLockToggleResult> setEnabled({
    required bool enabled,
    required LocalAuthentication auth,
    String reason = 'تفعيل قفل التطبيق',
    void Function()? onEnabled,
    void Function()? onDisabled,
  }) async {
    // Turning off needs no confirmation.
    if (!enabled) {
      final prefs = await AppPrefs.instance;
      await prefs.setBool(prefsKey, false);
      onDisabled?.call();
      return AppLockToggleResult.disabled;
    }

    // Turning on: the device must confirm it is the owner first.
    final supported = await auth.isDeviceSupported();
    if (!supported) {
      return AppLockToggleResult.unsupported;
    }

    try {
      final authenticated = await auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );

      if (!authenticated) {
        return AppLockToggleResult.cancelled;
      }
    } on LocalAuthException {
      return AppLockToggleResult.cancelled;
    } catch (_) {
      return AppLockToggleResult.cancelled;
    }

    // Confirmed: lock from the next launch on.
    final prefs = await AppPrefs.instance;
    await prefs.setBool(prefsKey, true);
    onEnabled?.call();
    return AppLockToggleResult.enabled;
  }
}
