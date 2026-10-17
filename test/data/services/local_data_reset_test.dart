// LocalDataReset.resetCurrentDevice: every pref, the session and each
// store's memory are cleared, so the app reads as a fresh install.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/auth_session.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/models/app_notification.dart';
import 'package:waffr/data/services/local_data_reset.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/services/smart_settings.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import '../../helpers/store_harness.dart';

void main() {
  setUp(() async {
    await setUpStores();
  });

  test('wipes prefs, the session and the stores', () async {
    final prefs = await setUpStores();
    await TransactionStore.instance.addIncome(amount: 100);
    await CurrencyStore.instance.addCurrency('USD');
    await CurrencyStore.instance.setActive('USD');
    await ShoppingListStore.instance.addItem('خبز');
    await CategoryStore.instance.addCustom('قهوة');
    await NotificationService.instance.add(
      type: NotificationType.goalReached,
      title: 't',
      message: 'm',
      eventKey: 'k',
    );
    await SmartSettings.instance.setAlerts(false);
    await const FlutterSecureStorage().write(
      key: AuthSession.tokenKey,
      value: 'jwt',
    );
    await prefs.setString(AuthSession.dataOwnerKey, 'a@b.co');

    await LocalDataReset.resetCurrentDevice();

    expect(prefs.getKeys(), isEmpty);
    expect(await AuthSession.instance.isLoggedIn(), isFalse);
    expect(await AuthSession.instance.dataOwnerEmail(), isNull);

    await TransactionStore.instance.ensureLoaded();
    await CurrencyStore.instance.ensureLoaded();
    await ShoppingListStore.instance.ensureLoaded();
    await CategoryStore.instance.ensureLoaded();
    await NotificationService.instance.ensureLoaded();
    await SmartSettings.instance.ensureLoaded();
    expect(TransactionStore.instance.transactions, isEmpty);
    expect(CurrencyStore.instance.activeCode, 'SYP');
    expect(ShoppingListStore.instance.items, isEmpty);
    expect(CategoryStore.instance.entries, isEmpty);
    expect(NotificationService.instance.notifications, isEmpty);
    expect(SmartSettings.instance.alerts, isTrue);
  });

  test('pending sync deletes do not outlive the wipe', () async {
    await ShoppingListStore.instance.addItem('خبز');
    await ShoppingListStore.instance.removeItem(
      ShoppingListStore.instance.items.single.id,
    );
    expect(
      SyncTombstones.instance.of(SyncCollection.shoppingItems),
      hasLength(1),
    );

    await LocalDataReset.resetCurrentDevice();

    expect(SyncTombstones.instance.of(SyncCollection.shoppingItems), isEmpty);
  });
}
