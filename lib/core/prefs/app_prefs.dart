// Cached SharedPreferences handle so screens and stores avoid repeated platform reads.

import 'package:shared_preferences/shared_preferences.dart';

/// One in-memory prefs instance for the whole app.
class AppPrefs {
  AppPrefs._();

  static SharedPreferences? _cached;
  static Future<SharedPreferences>? _loading;

  /// Warms the cache before the first frame when possible.
  static Future<void> warmUp() async {
    await instance;
  }

  /// Cached instance after [warmUp], or null if startup has not finished.
  static SharedPreferences? get cached => _cached;

  /// The shared instance; loads it once, then answers from memory.
  static Future<SharedPreferences> get instance {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _loading ??= _load();
  }

  static Future<SharedPreferences> _load() async {
    final loaded = await SharedPreferences.getInstance();
    _cached = loaded;
    _loading = null;
    return loaded;
  }
}
