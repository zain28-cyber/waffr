// Last-write-wins merge of remote upserts/deletes into an in-memory local list.

import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';

/// Applies server deletes, then upserts, to [items] in place. Returns true
/// when anything changed.
///
/// A local tombstone that is newer than an incoming upsert wins, so an
/// offline delete is not resurrected by an old row. [idOf] and [updatedOf]
/// read a record's id and last-change time.
bool mergeRemoteRecords<T>({
  required List<T> items,
  required List<T> upserts,
  required List<SyncTombstone> deletes,
  required SyncCollection collection,
  required String Function(T item) idOf,
  required DateTime Function(T item) updatedOf,
}) {
  // Deletes: drop local rows the server removed after their last change.
  var changed = false;
  final byId = <String, T>{for (final item in items) idOf(item): item};

  for (final tombstone in deletes) {
    final existing = byId[tombstone.clientId];
    if (existing == null) continue;
    if (!newerOrEqual(tombstone.deletedAt, updatedOf(existing))) {
      continue;
    }
    items.removeWhere((item) => idOf(item) == tombstone.clientId);
    byId.remove(tombstone.clientId);
    changed = true;
  }

  // Upserts: new rows are appended, strictly newer rows replace local ones.
  // The index map is built lazily on the first replacement; appends do not
  // move indexes.
  Map<String, int>? indexById;
  for (final incoming in upserts) {
    final id = idOf(incoming);
    final localTomb = SyncTombstones.instance.find(collection, id);
    if (localTomb != null &&
        newerOrEqual(localTomb.deletedAt, updatedOf(incoming))) {
      continue;
    }

    // Only strictly newer rows replace local ones. The server echoes back
    // the rows this device just pushed with the same timestamp; counting
    // those as changes re-saved every store and rebuilt every screen after
    // each sync.
    final existing = byId[id];
    if (existing != null && !updatedOf(incoming).isAfter(updatedOf(existing))) {
      continue;
    }

    if (existing == null) {
      items.add(incoming);
    } else {
      final index = (indexById ??= {
        for (var i = 0; i < items.length; i++) idOf(items[i]): i,
      })[id];
      if (index != null && index < items.length && idOf(items[index]) == id) {
        items[index] = incoming;
      } else {
        final found = items.indexWhere((item) => idOf(item) == id);
        if (found >= 0) items[found] = incoming;
      }
    }
    byId[id] = incoming;
    changed = true;
  }

  return changed;
}
