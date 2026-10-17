// SmartSettings: both switches default on, persist to prefs, notify, and
// return to the defaults after resetCache.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/services/smart_settings.dart';

import '../../helpers/store_harness.dart';

void main() {
  final settings = SmartSettings.instance;

  setUp(() async {
    await setUpStores();
  });

  test('both switches start on', () async {
    await settings.ensureLoaded();
    expect(settings.alerts, isTrue);
    expect(settings.categorize, isTrue);
  });

  test('changes are saved and read back', () async {
    final prefs = await setUpStores();
    var calls = 0;
    void listener() => calls++;
    settings.addListener(listener);
    addTearDown(() => settings.removeListener(listener));

    await settings.setAlerts(false);
    await settings.setCategorize(false);
    expect(calls, 2);
    expect(prefs.getBool(SmartSettings.alertsKey), isFalse);
    expect(prefs.getBool(SmartSettings.categorizeKey), isFalse);

    settings.resetCache();
    expect(settings.alerts, isTrue, reason: 'defaults until loaded');
    await settings.ensureLoaded();
    expect(settings.alerts, isFalse);
    expect(settings.categorize, isFalse);
  });
}
