// ApiConfig: the base URL (default or prefs override without a trailing
// slash) and the longer timeout for sleeping Render hosts.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/api_config.dart';

import '../../helpers/store_harness.dart';

void main() {
  test('Render hosts get 75 seconds, others the local timeout', () {
    expect(
      ApiConfig.timeoutFor('https://waffer-api.onrender.com'),
      const Duration(seconds: 75),
    );
    expect(
      ApiConfig.timeoutFor('https://ONRENDER.com/x'),
      const Duration(seconds: 75),
    );
    expect(
      ApiConfig.timeoutFor('http://localhost:8000'),
      const Duration(seconds: 25),
    );
    expect(
      ApiConfig.timeoutFor(
        'https://notonrender.com',
        local: const Duration(seconds: 3),
      ),
      const Duration(seconds: 3),
    );
    expect(ApiConfig.timeoutFor('::bad::'), const Duration(seconds: 25));
  });

  test('base URL defaults to production and honors an override', () async {
    final prefs = await setUpStores();
    expect(await ApiConfig.baseUrl(), ApiConfig.defaultBaseUrl);

    await prefs.setString(ApiConfig.overrideKey, '  http://10.0.2.2:8000/ ');
    expect(await ApiConfig.baseUrl(), 'http://10.0.2.2:8000');

    await prefs.setString(ApiConfig.overrideKey, '   ');
    expect(await ApiConfig.baseUrl(), ApiConfig.defaultBaseUrl);
  });
}
