// Builds the plain (unsealed) /sync request from the on-device stores.

import 'package:waffr/core/sync/profile_sync.dart';
import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/sync/sync_mapper.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/expense_preset_store.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

/// The push body: every collection's upserts and tombstones, plus settings.
///
/// With [everyRow] all rows are included (a full push, or a push after a
/// local edit that the fingerprint filter in sync_codec.dart narrows down).
/// Without it only rows stamped at or after [lastSync] go out, which is the
/// cheap "nothing changed here" pull. Tombstones always go out, so offline
/// deletes reach the server.
Future<Map<String, dynamic>> buildSyncRequest({
  required DateTime? lastSync,
  required bool everyRow,
}) async {
  await Future.wait<void>([
    TransactionStore.instance.ensureLoaded(),
    ShoppingListStore.instance.ensureLoaded(),
    RecurringExpenseStore.instance.ensureLoaded(),
    NotificationService.instance.ensureLoaded(),
    CategoryStore.instance.ensureLoaded(),
    ExpensePresetStore.instance.ensureLoaded(),
    SyncTombstones.instance.ensureLoaded(),
  ]);

  bool include(DateTime updatedAt) =>
      everyRow || lastSync == null || newerOrEqual(updatedAt, lastSync);

  // Ledger rows: incomes and expenses are transactions; savings moves are
  // transfers on the server.
  final store = TransactionStore.instance;
  final transactions = <Map<String, dynamic>>[];
  final transfers = <Map<String, dynamic>>[];
  for (final item in store.transactions) {
    if (!include(item.syncUpdatedAt)) continue;
    if (item.isSavingsIn || item.isSavingsOut) {
      transfers.add(transferToSync(item));
    } else {
      transactions.add(transactionToSync(item));
    }
  }

  final goals = [
    for (final goal in store.goals)
      if (include(goal.syncUpdatedAt)) goalToSync(goal),
  ];

  // Items belong to the one default list, which goes along with them.
  final items = [
    for (final item in ShoppingListStore.instance.items)
      if (include(item.syncUpdatedAt)) item.toSyncJson(),
  ];
  final lists = (everyRow || items.isNotEmpty || lastSync == null)
      ? [shoppingListToSync()]
      : <Map<String, dynamic>>[];

  final recurring = [
    for (final item in RecurringExpenseStore.instance.items)
      if (include(item.syncUpdatedAt)) recurringToSync(item),
  ];

  final notifications = [
    for (final item in NotificationService.instance.notifications)
      if (include(item.syncUpdatedAt)) notificationToSync(item),
  ];

  final categories = [
    for (final item in CategoryStore.instance.entries)
      if (include(item.syncUpdatedAt)) categoryToSync(item),
  ];

  final presets = [
    for (final item in ExpensePresetStore.instance.items)
      if (include(item.syncUpdatedAt)) item.toSyncJson(),
  ];

  // Settings are one small object; send them whenever they may have changed.
  final settingsUpdated = await SyncDirty.settingsUpdatedAt();
  final includeSettings =
      everyRow ||
      lastSync == null ||
      (settingsUpdated != null && newerOrEqual(settingsUpdated, lastSync));

  final tombstones = SyncTombstones.instance;
  Map<String, dynamic> section(
    List<Map<String, dynamic>> upserts,
    SyncCollection collection,
  ) {
    return collectionPayload(
      upserts: upserts,
      deletes: tombstones.of(collection),
    );
  }

  return {
    'last_sync_at': lastSync == null ? null : toSyncIso(lastSync),
    'transactions': section(transactions, SyncCollection.transactions),
    'savings_goals': section(goals, SyncCollection.savingsGoals),
    'savings_transfers': section(transfers, SyncCollection.savingsTransfers),
    'shopping_lists': section(lists, SyncCollection.shoppingLists),
    'shopping_items': section(items, SyncCollection.shoppingItems),
    'recurring_expenses': section(recurring, SyncCollection.recurringExpenses),
    'notifications': section(notifications, SyncCollection.notifications),
    'expense_categories': section(categories, SyncCollection.expenseCategories),
    'expense_presets': section(presets, SyncCollection.expensePresets),
    'settings': includeSettings ? await syncSettingsPayload() : null,
  };
}

/// Snapshot of the prefs-backed settings (income, currencies, profile,
/// streak) for the push.
Future<Map<String, dynamic>> syncSettingsPayload() async {
  final store = TransactionStore.instance;
  return {
    'notifications_muted': NotificationService.instance.isMuted,
    'notifications_enabled': !NotificationService.instance.isMuted,
    'monthly_income_amount': store.monthlyIncomeOverrideFor(
      defaultCurrencyCode,
    ),
    'weekly_income_amount': store.weeklyIncomeOverrideFor(defaultCurrencyCode),
    'income_overrides_by_currency': store.incomeOverridesByCurrencyPayload,
    'enabled_currencies': CurrencyStore.instance.enabledCodes,
    'active_currency': CurrencyStore.instance.activeCode,
    'processed_period_keys': store.processedPeriodTokens.toList(),
    'hidden_categories': CategoryStore.instance.hiddenBuiltIns,
    ...await ProfileSync.fields(),
    'updated_at': toSyncIso(await SyncDirty.settingsUpdatedAt()),
  };
}

/// Client ids of every tombstone in [request], per collection key.
Map<String, Iterable<String>> tombstoneIdsIn(Map<String, dynamic> request) {
  return {
    for (final entry in request.entries)
      if (entry.value is Map && (entry.value as Map)['deletes'] is List)
        entry.key: [
          for (final item in (entry.value as Map)['deletes'] as List)
            if (item is Map && item['client_id'] != null)
              item['client_id'].toString(),
        ],
  };
}
