// Wipes every piece of Waffr data on this device: prefs, the session,
// and each store's memory.

import 'package:waffr/data/stores/expense_preset_store.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/services/profile_identity.dart';
import 'package:waffr/data/services/system_notifications.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/services/smart_settings.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/sync/auth_session.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';

/// Wipes Waffr data on this device only (prefs, session, store caches).
class LocalDataReset {
  LocalDataReset._();

  /// Clears prefs/session, then resets every in-memory store cache.
  static Future<void> resetCurrentDevice() async {
    final prefs = await AppPrefs.instance;

    await prefs.clear();
    await AuthSession.instance.clearSession();
    await AuthSession.instance.clearDataOwner();

    TransactionStore.instance.resetCache();
    CurrencyStore.instance.resetCache();
    NotificationService.instance.resetCache();
    UsageStreakService.instance.resetCache();
    ProfileIdentity.instance.reset();
    await SystemNotifications.instance.cancelAll();
    ShoppingListStore.instance.resetCache();
    RecurringExpenseStore.instance.resetCache();
    CategoryStore.instance.resetCache();
    ExpensePresetStore.instance.resetCache();
    SyncTombstones.instance.resetCache();
    SmartSettings.instance.resetCache();
  }
}
