// Resolves the FastAPI base URL for sync and auth HTTP calls.

import 'package:waffr/core/prefs/app_prefs.dart';

/// Where the Waffr API lives and how long to wait for it.
class ApiConfig {
  ApiConfig._();

  /// Prefs key of a base-URL override (debug builds, local servers).
  static const String overrideKey = 'waffer_api_base_url';

  /// Production API deployed from render.yaml (Render Blueprint).
  static const String defaultBaseUrl = 'https://waffer-api.onrender.com';

  /// The request timeout for [baseUrl]: free Render instances take about a
  /// minute to wake after they sleep, so they get 75 seconds; others [local].
  static Duration timeoutFor(
    String baseUrl, {
    Duration local = const Duration(seconds: 25),
  }) {
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
    if (host == 'onrender.com' || host.endsWith('.onrender.com')) {
      return const Duration(seconds: 75);
    }
    return local;
  }

  /// The base URL without a trailing slash; the prefs override wins when set.
  static Future<String> baseUrl() async {
    final prefs = await AppPrefs.instance;
    final override = prefs.getString(overrideKey)?.trim() ?? '';
    if (override.isEmpty) return defaultBaseUrl;
    return override.endsWith('/')
        ? override.substring(0, override.length - 1)
        : override;
  }
}
