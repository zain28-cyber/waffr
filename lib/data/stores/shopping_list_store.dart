// Local shopping list; purchase completion creates expenses via TransactionStore.

import 'package:flutter/foundation.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/data/models/shopping_item.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/sync/sync_merge.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/core/prefs/app_prefs.dart';

export 'package:waffr/data/models/shopping_item.dart';

/// Shopping list in prefs. Expenses are created through TransactionStore
/// so balance and history stay consistent.
class ShoppingListStore extends ChangeNotifier {
  ShoppingListStore._();

  /// The app-wide shopping list.
  static final ShoppingListStore instance = ShoppingListStore._();

  /// Prefs key of the items (one JSON string each).
  static const String itemsKey = 'shopping_list_items';

  final List<ShoppingItem> _items = [];

  Future<void>? _loader;
  bool _loaded = false;

  /// True once loaded from prefs.
  bool get isLoaded => _loaded;

  /// Every item, newest first.
  List<ShoppingItem> get items => List.unmodifiable(_items);

  /// Loads from prefs once; later calls return the same future.
  Future<void> ensureLoaded() => _loader ??= _load();

  /// Adds an item at the top; blank names are ignored.
  Future<void> addItem(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    await ensureLoaded();

    _items.insert(
      0,
      ShoppingItem(id: _newId(), name: trimmed, createdAt: deviceNow()),
    );

    await _persist();
    notifyListeners();
  }

  /// New name only; a recorded purchase keeps its expense as it was.
  Future<bool> renameItem(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    await ensureLoaded();

    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return false;
    if (_items[index].name == trimmed) return true;

    _items[index] = _items[index].copyWith(name: trimmed);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Removes one item. A recorded purchase stays in the expense history.
  Future<bool> removeItem(String id) async {
    await ensureLoaded();

    final before = _items.length;
    _items.removeWhere((item) => item.id == id);
    if (_items.length == before) return false;

    await SyncTombstones.instance.add(SyncCollection.shoppingItems, id);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Removes every item, logging the deletes for sync.
  Future<void> clearAll() async {
    await ensureLoaded();
    if (_items.isEmpty) return;

    await SyncTombstones.instance.addMany(
      SyncCollection.shoppingItems,
      _items.map((item) => item.id),
    );
    _items.clear();
    await _persist();
    notifyListeners();
  }

  /// Marks purchased and posts an expense tagged with shopping:itemId.
  Future<bool> completePurchase({
    required String itemId,
    required double amount,
    required String category,
    String? currencyCode,
  }) async {
    if (amount <= 0) return false;

    await ensureLoaded();

    final index = _items.indexWhere((item) => item.id == itemId);
    if (index < 0) return false;

    final item = _items[index];
    if (item.isPurchased) return true;

    final expense = await TransactionStore.instance.addExpense(
      amount: amount,
      category: category,
      paymentMethod: paymentMethods.first,
      note: item.name,
      sourceId: 'shopping:$itemId',
      currencyCode: currencyCode,
    );

    if (expense == null) return false;

    final latestIndex = _items.indexWhere((entry) => entry.id == itemId);
    if (latestIndex < 0) return false;

    final latest = _items[latestIndex];
    _items[latestIndex] = latest.copyWith(
      isPurchased: true,
      purchasedAt: deviceNow(),
      expenseId: expense.id,
    );

    await _persist();
    notifyListeners();

    return true;
  }

  /// Clears purchase state when the linked expense is undone.
  Future<void> revertPurchaseForExpense(String expenseId) async {
    await ensureLoaded();

    final index = _items.indexWhere((item) => item.expenseId == expenseId);
    if (index < 0) return;

    _items[index] = _items[index].copyWith(clearPurchase: true);
    await _persist();
    notifyListeners();
  }

  /// Merges the server's items.
  Future<void> applyRemoteSync({
    required List<Map<String, dynamic>> upserts,
    required List<SyncTombstone> deletes,
  }) async {
    await ensureLoaded();

    final changed = mergeRemoteRecords<ShoppingItem>(
      items: _items,
      upserts: [
        for (final raw in upserts)
          if (ShoppingItem.fromSync(raw) != null) ShoppingItem.fromSync(raw)!,
      ],
      deletes: deletes,
      collection: SyncCollection.shoppingItems,
      idOf: (item) => item.id,
      updatedOf: (item) => item.syncUpdatedAt,
    );

    if (!changed) return;

    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _persist();
    notifyListeners();
  }

  /// Drops memory so the next [ensureLoaded] re-reads prefs (tests, wipes).
  void resetCache() {
    _items.clear();
    _loaded = false;
    _loader = null;
    notifyListeners();
  }

  Future<void> _load() async {
    final prefs = await AppPrefs.instance;
    final stored = prefs.getStringList(itemsKey) ?? const [];

    _items
      ..clear()
      ..addAll(stored.map(ShoppingItem.decode).whereType<ShoppingItem>())
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await AppPrefs.instance;
    await prefs.setStringList(
      itemsKey,
      _items.map((item) => item.encode()).toList(),
    );
    await SyncDirty.mark();
  }

  static int _sequence = 0;

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
}
