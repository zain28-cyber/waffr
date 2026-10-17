// Shared setup for tests that touch prefs-backed stores and services: a fresh
// in-memory SharedPreferences, mocked secure storage, and every singleton's
// in-memory cache dropped so each test starts from an empty device.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/security/data_key.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/services/profile_identity.dart';
import 'package:waffr/data/services/smart_settings.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/expense_preset_store.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

/// Gives the test an empty device and returns the cached prefs instance.
///
/// [AppPrefs] caches one [SharedPreferences] for the whole test process, so
/// swapping the mock store alone is not enough: the cached instance is
/// cleared too. Seed values with the returned prefs (`prefs.setString…`)
/// and then call [resetStoreCaches] so the stores re-read them.
Future<SharedPreferences> setUpStores() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final prefs = await AppPrefs.instance;
  await prefs.clear();
  await DataKeyStore.instance.clear();
  resetStoreCaches();
  return prefs;
}

/// Drops every store's memory so the next `ensureLoaded` reads prefs again,
/// and restores the static switches tests may have changed.
void resetStoreCaches() {
  TransactionStore.instance.resetCache();
  CurrencyStore.instance.resetCache();
  CategoryStore.instance.resetCache();
  ExpensePresetStore.instance.resetCache();
  ShoppingListStore.instance.resetCache();
  RecurringExpenseStore.instance.resetCache();
  NotificationService.instance.resetCache();
  UsageStreakService.instance.resetCache();
  UsageStreakService.clock = DateTime.now;
  SmartSettings.instance.resetCache();
  SyncTombstones.instance.resetCache();
  ProfileIdentity.instance.reset();
  SyncDirty.suppressed = false;
}
