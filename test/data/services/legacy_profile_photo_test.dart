// LegacyProfilePhoto.remove: the old photo prefs are deleted, and a missing
// path_provider plugin (as in tests) does not throw.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/services/legacy_profile_photo.dart';

import '../../helpers/store_harness.dart';

void main() {
  test('drops the old photo keys and never throws', () async {
    final prefs = await setUpStores();
    await prefs.setString('user_photo_path', '/tmp/x.jpg');
    await prefs.setString('user_photo_updated_at', '2025-01-01');
    await prefs.setBool('user_photo_pending', true);
    await prefs.setString('user_name', 'keep');

    await LegacyProfilePhoto.remove();

    expect(prefs.getKeys(), {'user_name'});
  });
}
