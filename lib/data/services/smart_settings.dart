// On/off switches for the smart features. Both run on the device and
// start on; the AI settings screen turns them off.

import 'package:flutter/foundation.dart';
import 'package:waffr/core/prefs/app_prefs.dart';

/// The smart-feature switches, saved in prefs.
class SmartSettings extends ChangeNotifier {
  SmartSettings._();

  /// The app-wide switches.
  static final SmartSettings instance = SmartSettings._();

  /// Prefs key of [alerts].
  static const String alertsKey = 'smart_alerts_enabled';

  /// Prefs key of [categorize].
  static const String categorizeKey = 'smart_categorize_enabled';

  bool _alerts = true;
  bool _categorize = true;
  Future<void>? _loader;

  /// Balance forecast and other smart notifications.
  bool get alerts => _alerts;

  /// Picking the category from the note while adding an expense.
  bool get categorize => _categorize;

  /// Loads from prefs once.
  Future<void> ensureLoaded() => _loader ??= _load();

  Future<void> _load() async {
    final prefs = await AppPrefs.instance;
    _alerts = prefs.getBool(alertsKey) ?? true;
    _categorize = prefs.getBool(categorizeKey) ?? true;
    notifyListeners();
  }

  /// Turns smart alerts on or off.
  Future<void> setAlerts(bool value) async {
    _alerts = value;
    notifyListeners();
    final prefs = await AppPrefs.instance;
    await prefs.setBool(alertsKey, value);
  }

  /// Turns category suggestions on or off.
  Future<void> setCategorize(bool value) async {
    _categorize = value;
    notifyListeners();
    final prefs = await AppPrefs.instance;
    await prefs.setBool(categorizeKey, value);
  }

  /// After a local data wipe the defaults come back.
  void resetCache() {
    _alerts = true;
    _categorize = true;
    _loader = null;
    notifyListeners();
  }
}
