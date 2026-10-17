// Profile photos were removed; this deletes what older versions left behind.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waffr/core/prefs/app_prefs.dart';

/// Cleans up the profile photo older versions saved.
class LegacyProfilePhoto {
  LegacyProfilePhoto._();

  static const List<String> _prefsKeys = [
    'user_photo_path',
    'user_photo_updated_at',
    'user_photo_pending',
  ];

  /// Deletes the old photo file and its prefs. Safe to call on every launch.
  static Future<void> remove() async {
    try {
      final prefs = await AppPrefs.instance;
      for (final key in _prefsKeys) {
        await prefs.remove(key);
      }
      if (kIsWeb) return;
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/waffer_profile_photo.jpg');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
