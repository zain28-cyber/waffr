// CurrencyStore: the enabled list (SYP always first), switching the active
// currency, add/remove rules, cycling, remote settings and prefs reload.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/data/stores/currency_store.dart';

import '../../helpers/store_harness.dart';

void main() {
  final store = CurrencyStore.instance;
  late SharedPreferences prefs;

  setUp(() async {
    prefs = await setUpStores();
  });

  test('starts with SYP only and active', () async {
    await store.ensureLoaded();
    expect(store.isLoaded, isTrue);
    expect(store.enabledCodes, ['SYP']);
    expect(store.activeCode, 'SYP');
    expect(store.activeSymbol, 'ل.س');
    expect(store.active.code, 'SYP');
    expect(store.availableToAdd.map((c) => c.code), isNot(contains('SYP')));
    expect(store.availableToAdd, hasLength(Currencies.catalog.length - 1));
  });

  test('adding accepts known non-SYP codes once', () async {
    expect(await store.addCurrency('usd'), isTrue);
    expect(await store.addCurrency('USD'), isFalse);
    expect(await store.addCurrency('SYP'), isFalse);
    expect(await store.addCurrency('XYZ'), isFalse);
    expect(store.enabledCodes, ['SYP', 'USD']);
    expect(store.isEnabled('usd'), isTrue);
    expect(store.enabledCurrencies.last.arabicName, 'دولار أمريكي');
    expect(await SyncDirty.isDirty(), isTrue);
    expect(await SyncDirty.settingsUpdatedAt(), isNotNull);
  });

  test('only enabled currencies can be active', () async {
    await store.setActive('EUR');
    expect(store.activeCode, 'SYP');
    await store.addCurrency('EUR');
    await store.setActive('eur');
    expect(store.activeCode, 'EUR');
    expect(store.activeSymbol, '€');
  });

  test('removing the active currency falls back to SYP', () async {
    await store.addCurrency('EUR');
    await store.setActive('EUR');
    expect(await store.removeCurrency('SYP'), isFalse);
    expect(await store.removeCurrency('USD'), isFalse);
    expect(await store.removeCurrency('EUR'), isTrue);
    expect(store.activeCode, 'SYP');
    expect(store.enabledCodes, ['SYP']);
  });

  test('next and previous wrap around', () async {
    await store.selectNext();
    expect(store.activeCode, 'SYP', reason: 'nothing to cycle to');

    await store.addCurrency('USD');
    await store.addCurrency('EUR');
    await store.selectNext();
    expect(store.activeCode, 'USD');
    await store.selectNext();
    expect(store.activeCode, 'EUR');
    await store.selectNext();
    expect(store.activeCode, 'SYP');
    await store.selectPrevious();
    expect(store.activeCode, 'EUR');
  });

  test('the choice survives a reload; bad stored codes are dropped', () async {
    await prefs.setStringList(CurrencyStore.enabledKey, [
      'usd',
      'SYP',
      'XYZ',
      'USD',
      'try',
    ]);
    await prefs.setString(CurrencyStore.activeKey, 'try');
    resetStoreCaches();
    await store.ensureLoaded();
    expect(store.enabledCodes, ['SYP', 'USD', 'TRY']);
    expect(store.activeCode, 'TRY');

    await prefs.setString(CurrencyStore.activeKey, 'EUR');
    resetStoreCaches();
    await store.ensureLoaded();
    expect(store.activeCode, 'SYP', reason: 'EUR is not enabled');
  });

  group('applyRemote', () {
    test('replaces the list and active code', () async {
      await store.addCurrency('EUR');
      await store.applyRemote(enabled: ['USD', 'GBP', 'bogus'], active: 'gbp');
      expect(store.enabledCodes, ['SYP', 'USD', 'GBP']);
      expect(store.activeCode, 'GBP');
      expect(prefs.getStringList(CurrencyStore.enabledKey), [
        'SYP',
        'USD',
        'GBP',
      ]);
    });

    test('an active code outside the list falls back to SYP', () async {
      await store.applyRemote(enabled: ['USD'], active: 'EUR');
      expect(store.activeCode, 'SYP');
    });

    test('nothing given or nothing changed is a no-op', () async {
      var calls = 0;
      void listener() => calls++;
      await store.ensureLoaded();
      store.addListener(listener);
      addTearDown(() => store.removeListener(listener));

      await store.applyRemote();
      await store.applyRemote(active: '  ');
      await store.applyRemote(enabled: ['SYP'], active: 'SYP');
      expect(calls, 0);
    });

    test('active alone switches within the current list', () async {
      await store.addCurrency('USD');
      await store.applyRemote(active: 'USD');
      expect(store.activeCode, 'USD');
    });
  });
}
