// Dirty flag: tracks whether local data changed since the last successful sync.

import 'package:flutter/foundation.dart';
import 'package:waffr/core/prefs/app_prefs.dart';

/// Persists a "needs push" bit and an optional settings timestamp so
/// [SyncService] knows when local rows have to go to the server.
class SyncDirty {
  SyncDirty._();

  /// Prefs key of the "needs push" bit.
  static const String key = 'waffer_sync_dirty';

  /// Prefs key of the last local settings change (UTC ISO string).
  static const String settingsUpdatedAtKey = 'waffer_settings_updated_at';

  /// When true, applying a remote pull will not re-mark local data as dirty.
  static bool suppressed = false;

  static final List<VoidCallback> _listeners = <VoidCallback>[];

  static int _revision = 0;

  /// Grows with every [mark] in this process. A sync reads it before it
  /// builds its request, so an edit made while the request is in flight
  /// keeps the flag set (see [clear]).
  static int get revision => _revision;

  /// Calls [listener] after every [mark] (used to schedule a sync).
  static void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// Stops calling [listener] on [mark].
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Flips the dirty bit after a local edit; with [settings] it also stamps
  /// the settings change time used for last-write-wins on the server.
  static Future<void> mark({bool settings = false}) async {
    if (suppressed) return;
    _revision++;

    final prefs = await AppPrefs.instance;
    await prefs.setBool(key, true);
    if (settings) {
      await prefs.setString(
        settingsUpdatedAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    }

    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  /// True when something changed since the last successful sync.
  static Future<bool> isDirty() async {
    final prefs = await AppPrefs.instance;
    return prefs.getBool(key) ?? false;
  }

  /// Cleared only after a successful sync round-trip. With [ifRevision] the
  /// bit stays set when a [mark] happened after that revision was read,
  /// because that edit was not part of the request that just succeeded.
  static Future<void> clear({int? ifRevision}) async {
    if (ifRevision != null && ifRevision != _revision) return;
    final prefs = await AppPrefs.instance;
    await prefs.setBool(key, false);
  }

  /// When settings last changed on this device, or null if never.
  static Future<DateTime?> settingsUpdatedAt() async {
    final prefs = await AppPrefs.instance;
    return DateTime.tryParse(prefs.getString(settingsUpdatedAtKey) ?? '')
        ?.toUtc();
  }

  /// Adopts the server's settings time after a newer remote copy is applied.
  static Future<void> setSettingsUpdatedAt(DateTime value) async {
    final prefs = await AppPrefs.instance;
    await prefs.setString(
      settingsUpdatedAtKey,
      value.toUtc().toIso8601String(),
    );
  }
}
