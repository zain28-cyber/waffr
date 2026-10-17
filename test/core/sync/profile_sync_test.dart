// ProfileSync: the profile fields pushed with settings, adopting an account
// profile, filling only empty fields, and applying newer remote settings.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/sync/profile_sync.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/data/stores/category_store.dart';

import '../../helpers/store_harness.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    prefs = await setUpStores();
  });

  test('fields reads the profile prefs and dark mode only when set', () async {
    await prefs.setString('user_name', 'سارة');
    await prefs.setString('user_city', 'حمص');
    var fields = await ProfileSync.fields();
    expect(fields['display_name'], 'سارة');
    expect(fields['city'], 'حمص');
    expect(fields['phone'], isNull);
    expect(fields.containsKey('dark_mode'), isFalse);

    await prefs.setBool('dark_mode', false);
    fields = await ProfileSync.fields();
    expect(fields['dark_mode'], isFalse);
  });

  test('adoptAccount replaces given fields and removes blank ones', () async {
    await prefs.setString('user_name', 'قديم');
    await prefs.setString('user_phone', '123');
    await prefs.setString('user_city', 'دمشق');

    await ProfileSync.adoptAccount({
      'name': ' جديد ',
      'phone': '',
      'country': 'سوريا',
    });

    expect(prefs.getString('user_name'), 'جديد');
    expect(prefs.getString('user_phone'), isNull);
    expect(prefs.getString('user_country'), 'سوريا');
    expect(prefs.getString('user_city'), 'دمشق', reason: 'not in the profile');
    expect(await SyncDirty.settingsUpdatedAt(), isNotNull);
  });

  test('fillMissing never overwrites local edits', () async {
    await prefs.setString('user_name', 'محلي');
    await ProfileSync.fillMissing({
      'name': 'حساب',
      'city': 'حلب',
      'street': ' ',
    });
    expect(prefs.getString('user_name'), 'محلي');
    expect(prefs.getString('user_city'), 'حلب');
    expect(prefs.getString('user_street'), isNull);
  });

  test('apply writes newer remote settings', () async {
    await ProfileSync.apply({
      'updated_at': '2026-01-01T00:00:00Z',
      'display_name': 'سارة',
      'gender': 'female',
      'phone': ' ',
      'dark_mode': true,
      'hidden_categories': ['تعليم'],
    });
    expect(prefs.getString('user_name'), 'سارة');
    expect(prefs.getString('user_gender'), 'female');
    expect(prefs.getString('user_phone'), isNull);
    expect(prefs.getBool('dark_mode'), isTrue);
    expect(CategoryStore.instance.hiddenBuiltIns, ['تعليم']);
  });

  test('apply ignores settings older than the local ones', () async {
    await SyncDirty.setSettingsUpdatedAt(DateTime.utc(2026, 6));
    await ProfileSync.apply({
      'updated_at': '2026-01-01T00:00:00Z',
      'display_name': 'قديم',
      'dark_mode': 'yes',
    });
    expect(prefs.getString('user_name'), isNull);
    expect(prefs.containsKey('dark_mode'), isFalse);
  });

  test('apply always merges the streak', () async {
    await SyncDirty.setSettingsUpdatedAt(DateTime.utc(2030));
    await ProfileSync.apply({
      'updated_at': '2026-01-01T00:00:00Z',
      'streak_count': 3,
      'streak_last_date': '2026-01-01',
    });
    final fields = await ProfileSync.fields();
    expect(fields['streak_count'], 3);
    expect(fields['streak_last_date'], '2026-01-01');
  });
}
