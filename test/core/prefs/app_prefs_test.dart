// AppPrefs: one cached SharedPreferences for the whole app, available
// synchronously after warmUp.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/prefs/app_prefs.dart';

void main() {
  test('instance is loaded once and cached', () async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.warmUp();
    final cached = AppPrefs.cached;
    expect(cached, isNotNull);

    final a = await AppPrefs.instance;
    final b = await AppPrefs.instance;
    expect(identical(a, b), isTrue);
    expect(identical(a, cached), isTrue);
  });

  test('writes are visible through every handle', () async {
    final prefs = await AppPrefs.instance;
    await prefs.setString('k', 'v');
    expect(AppPrefs.cached!.getString('k'), 'v');
    await prefs.remove('k');
  });
}
