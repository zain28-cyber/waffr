// BackupService (local account data): which prefs survive an account switch
// or deletion, the guest choice, the display name, and the reset listeners.
// Secure storage is mocked; nothing reaches the network.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/api_config.dart';
import 'package:waffr/core/sync/auth_session.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/data/services/backup_service.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import '../../helpers/store_harness.dart';

void main() {
  final backup = BackupService.instance;

  setUp(() async {
    await setUpStores();
  });

  test('an account switch wipes user data but keeps device keys', () async {
    final prefs = await setUpStores();
    await TransactionStore.instance.addIncome(amount: 500);
    await prefs.setBool('first_launch', false);
    await prefs.setBool('dark_mode', true);
    await prefs.setString('user_name', 'قديم');
    await prefs.setString(AuthSession.accountEmailKey, 'a@b.co');
    await prefs.setString(ApiConfig.overrideKey, 'http://localhost');
    await prefs.setBool(BackupService.authChoiceKey, true);

    await backup.replaceLocalDataForAccountSwitch();

    expect(TransactionStore.instance.transactions, isEmpty);
    expect(prefs.getStringList(TransactionStore.transactionsKey), isNull);
    expect(prefs.getString('user_name'), isNull);
    expect(prefs.getBool('first_launch'), isFalse);
    expect(prefs.getBool('dark_mode'), isTrue);
    expect(prefs.getString(AuthSession.accountEmailKey), 'a@b.co');
    expect(prefs.getString(ApiConfig.overrideKey), 'http://localhost');
    expect(prefs.getBool(BackupService.authChoiceKey), isTrue);
  });

  test(
    'continuing as a guest drops the session and records the choice',
    () async {
      final prefs = await setUpStores();
      await const FlutterSecureStorage().write(
        key: AuthSession.tokenKey,
        value: 'jwt',
      );
      await prefs.setString(AuthSession.accountEmailKey, 'a@b.co');

      await backup.continueAsGuest();

      expect(await AuthSession.instance.isLoggedIn(), isFalse);
      expect(prefs.getString(AuthSession.accountEmailKey), isNull);
      expect(prefs.getBool(BackupService.authChoiceKey), isTrue);
    },
  );

  test('deleting the account wipes data and tells the listeners', () async {
    final prefs = await setUpStores();
    await TransactionStore.instance.addIncome(amount: 500);
    await prefs.setString(AuthSession.dataOwnerKey, 'a@b.co');
    var resets = 0;
    void listener() => resets++;
    backup.addRestoreListener(listener);
    addTearDown(() => backup.removeRestoreListener(listener));

    await backup.deleteAccount();

    expect(resets, 1);
    expect(TransactionStore.instance.transactions, isEmpty);
    expect(prefs.getString(AuthSession.dataOwnerKey), isNull);
    expect(prefs.getBool(BackupService.authChoiceKey), isTrue);

    backup.removeRestoreListener(listener);
    await backup.deleteAccount();
    expect(resets, 1);
  });

  test('the display name is trimmed, saved and marks settings dirty', () async {
    final prefs = await setUpStores();
    await backup.updateDisplayName('   ');
    expect(prefs.getString('user_name'), isNull);

    await backup.updateDisplayName('  ليلى ');
    expect(prefs.getString('user_name'), 'ليلى');
    expect(await SyncDirty.settingsUpdatedAt(), isNotNull);
  });
}
