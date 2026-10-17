// Remembers which rows the server already holds, so a sync after a local
// edit sends only what changed instead of the whole ledger.

import 'package:waffr/core/sync/sync_codec.dart';

/// Fingerprints of rows the server acknowledged during this app session.
///
/// Kept in memory only. The first push after launch sends every row and
/// fills it; later pushes skip rows whose fingerprint did not change. A
/// sign-in, a forced sync or a first sync is always a full push, which
/// replaces the whole memory, so a new account or a new data key never
/// inherits another push's state.
class SyncSentRows {
  SyncRowPrints _prints = {};

  /// Fingerprints to compare against (a copy, safe to hand to an isolate).
  SyncRowPrints get known => {
    for (final entry in _prints.entries)
      entry.key: Map<String, String>.of(entry.value),
  };

  /// True when nothing has been remembered yet.
  bool get isEmpty => _prints.values.every((rows) => rows.isEmpty);

  /// Records a successful push.
  ///
  /// With [replace] (a full push) [sent] becomes the whole memory. Ids in
  /// [deleted] are forgotten: their tombstones reached the server, so the
  /// same id saved again later has to be pushed again.
  void remember(
    SyncRowPrints sent, {
    required bool replace,
    Map<String, Iterable<String>> deleted = const {},
  }) {
    if (replace) _prints = {};
    for (final entry in sent.entries) {
      _prints.putIfAbsent(entry.key, () => {}).addAll(entry.value);
    }
    for (final entry in deleted.entries) {
      final rows = _prints[entry.key];
      if (rows == null) continue;
      for (final id in entry.value) {
        rows.remove(id);
      }
    }
  }

  /// Forgets everything; the next push sends every row.
  void clear() => _prints = {};
}
