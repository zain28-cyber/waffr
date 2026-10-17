// Tombstones: local delete log so offline removals can reach the server later.

import 'dart:convert';

import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/prefs/app_prefs.dart';

/// Which synced collection a delete belongs to.
enum SyncCollection {
  /// Incomes and expenses.
  transactions,

  /// Savings goals.
  savingsGoals,

  /// Moves into and out of savings.
  savingsTransfers,

  /// Shopping lists (the app uses one default list).
  shoppingLists,

  /// Shopping-list items.
  shoppingItems,

  /// Recurring bills.
  recurringExpenses,

  /// In-app notifications.
  notifications,

  /// Custom expense categories.
  expenseCategories,

  /// Saved expenses (the star on the expense sheet).
  expensePresets,
}

/// One deleted client_id plus when it was removed on this device.
class SyncTombstone {
  /// The deleted row's client id.
  final String clientId;

  /// When it was deleted (UTC).
  final DateTime deletedAt;

  /// A delete of [clientId] at [deletedAt].
  const SyncTombstone({required this.clientId, required this.deletedAt});

  /// The JSON shape of a delete in the /sync API.
  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'deleted_at': toSyncIso(deletedAt),
  };

  /// Reads an API or prefs delete (snake or camel case); null without id.
  static SyncTombstone? decode(Object? raw) {
    if (raw is! Map) return null;
    final id =
        raw['client_id']?.toString().trim() ??
        raw['clientId']?.toString().trim() ??
        '';
    if (id.isEmpty) return null;
    return SyncTombstone(
      clientId: id,
      deletedAt: parseSyncDateOrNow(raw['deleted_at'] ?? raw['deletedAt']),
    );
  }
}

/// Persists deletes until SyncService pushes them and the server
/// acknowledges them. Without this, an offline delete would never leave the
/// device.
class SyncTombstones {
  SyncTombstones._();

  /// The app-wide delete log.
  static final SyncTombstones instance = SyncTombstones._();

  static const String _key = 'waffer_sync_tombstones';

  final Map<SyncCollection, Map<String, SyncTombstone>> _items = {
    for (final collection in SyncCollection.values) collection: {},
  };

  Future<void>? _loader;
  bool _loaded = false;

  /// Loads the log from prefs once; later calls return the same future.
  Future<void> ensureLoaded() => _loader ??= _load();

  /// Records a single offline delete for the next push.
  Future<void> add(SyncCollection collection, String clientId) async {
    await ensureLoaded();
    final id = clientId.trim();
    if (id.isEmpty) return;
    _items[collection]![id] = SyncTombstone(clientId: id, deletedAt: syncNow());
    await _persist();
  }

  /// Records several deletes in one write (e.g. clearing a list).
  Future<void> addMany(SyncCollection collection, Iterable<String> ids) async {
    await ensureLoaded();
    final now = syncNow();
    var changed = false;
    for (final raw in ids) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      _items[collection]![id] = SyncTombstone(clientId: id, deletedAt: now);
      changed = true;
    }
    if (changed) await _persist();
  }

  /// Pending deletes of [collection], as a read-only snapshot.
  List<SyncTombstone> of(SyncCollection collection) {
    return List<SyncTombstone>.unmodifiable(
      _items[collection]?.values ?? const [],
    );
  }

  /// The pending delete of [clientId], if any.
  SyncTombstone? find(SyncCollection collection, String clientId) {
    return _items[collection]?[clientId];
  }

  /// Drops tombstones after the server has seen those deletes.
  Future<void> remove(SyncCollection collection, Iterable<String> ids) async {
    await ensureLoaded();
    var changed = false;
    final bucket = _items[collection]!;
    for (final id in ids) {
      if (bucket.remove(id) != null) changed = true;
    }
    if (changed) await _persist();
  }

  /// Forgets every pending delete (local data wiped).
  Future<void> clearAll() async {
    await ensureLoaded();
    for (final bucket in _items.values) {
      bucket.clear();
    }
    await _persist();
  }

  /// Drops the in-memory log so the next [ensureLoaded] re-reads prefs.
  void resetCache() {
    for (final bucket in _items.values) {
      bucket.clear();
    }
    _loaded = false;
    _loader = null;
  }

  // Reads the per-collection lists saved by [_persist]; bad JSON is ignored.
  Future<void> _load() async {
    final prefs = await AppPrefs.instance;
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final collection in SyncCollection.values) {
            final list = decoded[collection.name];
            if (list is! List) continue;
            for (final item in list) {
              final tombstone = SyncTombstone.decode(item);
              if (tombstone == null) continue;
              _items[collection]![tombstone.clientId] = tombstone;
            }
          }
        }
      } catch (_) {}
    }
    _loaded = true;
  }

  // Saves every bucket as one JSON object keyed by collection name.
  Future<void> _persist() async {
    if (!_loaded) return;
    final prefs = await AppPrefs.instance;
    await prefs.setString(
      _key,
      jsonEncode({
        for (final collection in SyncCollection.values)
          collection.name: _items[collection]!.values
              .map((item) => item.toJson())
              .toList(),
      }),
    );
  }
}
