// Profile fields in prefs that travel with /sync settings (name, address, theme).

import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/stores/category_store.dart';

/// Reads and writes the on-device user profile used during login and sync push.
class ProfileSync {
  ProfileSync._();

  static const Map<String, String> _accountKeys = {
    'name': 'user_name',
    'gender': 'user_gender',
    'birthdate': 'user_birthdate',
    'country': 'user_country',
    'city': 'user_city',
    'street': 'user_street',
    'phone': 'user_phone',
  };

  /// Build the settings fragment sent on push.
  static Future<Map<String, dynamic>> fields() async {
    final prefs = await AppPrefs.instance;
    await UsageStreakService.instance.ensureLoaded();
    return {
      'display_name': prefs.getString('user_name'),
      'gender': prefs.getString('user_gender'),
      'birthdate': prefs.getString('user_birthdate'),
      'country': prefs.getString('user_country'),
      'city': prefs.getString('user_city'),
      'street': prefs.getString('user_street'),
      'phone': prefs.getString('user_phone'),
      if (prefs.containsKey('dark_mode'))
        'dark_mode': prefs.getBool('dark_mode'),
      ...UsageStreakService.instance.syncFields(),
    };
  }

  /// Replace local profile with the signed-in account so a prior user cannot linger.
  static Future<void> adoptAccount(Map<String, dynamic> profile) async {
    final prefs = await AppPrefs.instance;
    for (final entry in _accountKeys.entries) {
      if (!profile.containsKey(entry.key)) continue;
      final raw = profile[entry.key]?.toString().trim() ?? '';
      if (raw.isEmpty) {
        await prefs.remove(entry.value);
      } else {
        await prefs.setString(entry.value, raw);
      }
    }
    await SyncDirty.mark(settings: true);
  }

  /// Fill empty local fields from the account without overwriting user edits.
  static Future<void> fillMissing(Map<String, dynamic> profile) async {
    final prefs = await AppPrefs.instance;
    for (final entry in _accountKeys.entries) {
      final raw = profile[entry.key]?.toString().trim() ?? '';
      if (raw.isEmpty) continue;
      final existing = prefs.getString(entry.value)?.trim() ?? '';
      if (existing.isEmpty) {
        await prefs.setString(entry.value, raw);
      }
    }
  }

  /// Apply remote settings when the server copy is newer than local settings.
  static Future<void> apply(Map<String, dynamic> settings) async {
    await UsageStreakService.instance.applyRemote(settings);

    final remoteUpdated = parseSyncDate(settings['updated_at']);
    final localUpdated = await SyncDirty.settingsUpdatedAt();
    if (!newerOrEqual(remoteUpdated, localUpdated)) return;

    final prefs = await AppPrefs.instance;

    final name = settings['display_name']?.toString().trim() ?? '';
    if (name.isNotEmpty) {
      await prefs.setString('user_name', name);
    }

    const synced = {
      'gender': 'user_gender',
      'birthdate': 'user_birthdate',
      'country': 'user_country',
      'city': 'user_city',
      'street': 'user_street',
      'phone': 'user_phone',
    };
    for (final entry in synced.entries) {
      final value = settings[entry.key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        await prefs.setString(entry.value, value);
      }
    }

    if (settings.containsKey('dark_mode') && settings['dark_mode'] is bool) {
      await prefs.setBool('dark_mode', settings['dark_mode'] as bool);
    }

    if (settings.containsKey('hidden_categories')) {
      await CategoryStore.instance.applyRemoteHidden(
        settings['hidden_categories'],
      );
    }
  }
}
