// Merges an opened /sync reply into the on-device stores.

import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/sync/sync_mapper.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/stores/expense_preset_store.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

/// Applies remote upserts and deletes to every store, then drops the
/// tombstones the server has seen: those in [sentTombstones] (the request's
/// deletes, by wire collection key) and those the reply echoes. Returns
/// false when a store failed; local data is never wiped for a failed merge.
///
/// Dirty marks are suppressed meanwhile, so merging the server's rows does
/// not count as a local edit and start another push.
Future<bool> applySyncResponse(
  Map<String, dynamic> body, {
  Map<String, Iterable<String>> sentTombstones = const {},
}) async {
  try {
    SyncDirty.suppressed = true;

    // Ledger, goals and settings first: the other stores read balances.
    await TransactionStore.instance.applyRemoteSync(
      transactions: _upserts(body, 'transactions'),
      transactionDeletes: _deletes(body, 'transactions'),
      transfers: _upserts(body, 'savings_transfers'),
      transferDeletes: _deletes(body, 'savings_transfers'),
      goals: _upserts(body, 'savings_goals'),
      goalDeletes: _deletes(body, 'savings_goals'),
      settings: body['settings'] is Map
          ? Map<String, dynamic>.from(body['settings'] as Map)
          : null,
    );

    await CategoryStore.instance.applyRemoteSync(
      upserts: _upserts(body, 'expense_categories'),
      deletes: _deletes(body, 'expense_categories'),
    );

    await ExpensePresetStore.instance.applyRemoteSync(
      upserts: _upserts(body, 'expense_presets'),
      deletes: _deletes(body, 'expense_presets'),
    );

    await ShoppingListStore.instance.applyRemoteSync(
      upserts: _upserts(body, 'shopping_items'),
      deletes: _deletes(body, 'shopping_items'),
    );

    await RecurringExpenseStore.instance.applyRemoteSync(
      upserts: _upserts(body, 'recurring_expenses'),
      deletes: _deletes(body, 'recurring_expenses'),
    );

    await NotificationService.instance.applyRemoteSync(
      upserts: _upserts(body, 'notifications'),
      deletes: _deletes(body, 'notifications'),
      muted: mutedFromSyncSettings(body['settings']),
    );

    await _clearAcknowledgedTombstones(body, sentTombstones);
    return true;
  } catch (_) {
    return false;
  } finally {
    SyncDirty.suppressed = false;
  }
}

/// The mute switch from a settings payload; older servers only sent
/// `notifications_enabled`. Null when neither is present.
bool? mutedFromSyncSettings(Object? raw) {
  if (raw is! Map) return null;
  if (raw.containsKey('notifications_muted')) {
    return raw['notifications_muted'] == true;
  }
  if (raw.containsKey('notifications_enabled')) {
    return raw['notifications_enabled'] != true;
  }
  return null;
}

// Wire key of each synced collection.
const Map<String, SyncCollection> _collections = {
  'transactions': SyncCollection.transactions,
  'savings_goals': SyncCollection.savingsGoals,
  'savings_transfers': SyncCollection.savingsTransfers,
  'shopping_lists': SyncCollection.shoppingLists,
  'shopping_items': SyncCollection.shoppingItems,
  'recurring_expenses': SyncCollection.recurringExpenses,
  'notifications': SyncCollection.notifications,
  'expense_categories': SyncCollection.expenseCategories,
  'expense_presets': SyncCollection.expensePresets,
};

// After a successful round trip, remove local delete logs: the ones this
// push carried and the ones the server echoed back. A delete made while the
// request was in flight was not in it, so its tombstone stays for next time.
Future<void> _clearAcknowledgedTombstones(
  Map<String, dynamic> body,
  Map<String, Iterable<String>> sent,
) async {
  final tombstones = SyncTombstones.instance;
  for (final entry in _collections.entries) {
    final returned = _deletes(body, entry.key).map((item) => item.clientId);
    await tombstones.remove(entry.value, {...?sent[entry.key], ...returned});
  }
}

Map<String, dynamic> _section(Map<String, dynamic> body, String key) {
  final value = body[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _upserts(Map<String, dynamic> body, String key) =>
    asMapList(_section(body, key)['upserts']);

List<SyncTombstone> _deletes(Map<String, dynamic> body, String key) =>
    tombstonesFromSync(_section(body, key)['deletes']);
