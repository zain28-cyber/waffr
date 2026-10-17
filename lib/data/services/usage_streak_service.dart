// Local daily streak. Signed-in users also ship it inside settings sync.
// A local change stays flagged until a sync that carried it succeeds, so a
// streak update is never lost to a sync that was already in flight.

import 'package:flutter/foundation.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/usage/streak_math.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/insights/profile_snapshot.dart';
import 'package:waffr/core/prefs/app_prefs.dart';

/// A streak that just grew by a day on this device: [from] to [to].
class StreakIncrease {
  /// Streak before today.
  final int from;

  /// Streak after today counted.
  final int to;

  /// An increase.
  const StreakIncrease({required this.from, required this.to});
}

/// The daily-use streak, saved in prefs and merged with the account.
class UsageStreakService extends ChangeNotifier {
  UsageStreakService._();

  /// The app-wide service.
  static final UsageStreakService instance = UsageStreakService._();

  /// Prefs key of the streak count.
  static const String countKey = 'waffer_streak_count';

  /// Prefs key of the last counted day (YYYY-MM-DD).
  static const String lastDayKey = 'waffer_streak_last_date';

  /// Prefs key of the first day of use.
  static const String startedKey = 'waffer_usage_started_at';

  /// Prefs key of the "server may be behind" flag.
  static const String unsyncedKey = 'waffer_streak_unsynced';

  /// Clock for "today"; tests replace it.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  StreakSnapshot _state = const StreakSnapshot();
  Future<void>? _loader;
  bool _loaded = false;
  StreakIncrease? _pendingIncrease;

  // True while the server may hold an older streak than this device.
  bool _unsynced = true;

  // Bumped on every change the server has not seen yet.
  int _revision = 0;

  /// True once loaded from prefs.
  bool get isLoaded => _loaded;

  /// Days in a row as of today. A skipped day reads as 0 until the next
  /// open starts a new streak.
  int get count => StreakMath.currentCount(_state, clock());

  /// True when the streak must be sent on the next sync.
  bool get hasUnsyncedChange => _unsynced;

  /// Pass to [markSynced] after a sync that carried [syncFields].
  int get revision => _revision;

  /// The last counted day.
  DateTime? get lastDay => _state.lastDay;

  /// The first day of use.
  DateTime? get startedAt => _state.startedAt;

  /// "اليوم الأول", or the count of days in a row.
  String get label => StreakSnapshot(count: count).label;

  /// Loads from prefs once.
  Future<void> ensureLoaded() => _loader ??= _load();

  /// Records today once. Same calendar day does not increase the count.
  Future<StreakSnapshot> recordToday({DateTime? now}) async {
    await ensureLoaded();
    await TransactionStore.instance.ensureLoaded();

    final today = now ?? clock();
    var current = _state;
    if (current.startedAt == null) {
      current = StreakSnapshot(
        count: current.count,
        lastDay: current.lastDay,
        startedAt: earliestUsageDate(TransactionStore.instance) ?? today,
      );
    }

    final next = StreakMath.record(current, today);
    if (!StreakMath.differs(_state, next)) return _state;

    // Opening on the next calendar day: the home screen celebrates it once.
    final previous = _state.count;
    if (previous >= 1 && next.count == previous + 1) {
      _pendingIncrease = StreakIncrease(from: previous, to: next.count);
    }

    _state = next;
    _revision++;
    _unsynced = true;
    await _persist(markDirty: true);
    notifyListeners();
    return _state;
  }

  /// Merges a remote settings streak without letting an older day erase today.
  Future<void> applyRemote(Map<String, dynamic> settings) async {
    await ensureLoaded();
    final remote = StreakSnapshot(
      count: (settings['streak_count'] as num?)?.toInt() ?? 0,
      lastDay: StreakSnapshot.parseDayKey(
        settings['streak_last_date']?.toString(),
      ),
      startedAt: DateTime.tryParse(
        settings['usage_started_at']?.toString() ?? '',
      )?.toLocal(),
    );
    if (remote.lastDay == null &&
        remote.startedAt == null &&
        remote.count <= 0) {
      return;
    }

    final merged = StreakMath.merge(_state, remote);
    final changedLocal = StreakMath.differs(_state, merged);
    if (StreakMath.differs(remote, merged)) {
      // The server is behind this device; send the merged streak back.
      _revision++;
      await _setUnsynced(true);
    }
    if (!changedLocal) return;

    _state = merged;
    await _persist(markDirty: false);
    notifyListeners();
  }

  /// The streak fields of the settings push.
  Map<String, dynamic> syncFields() {
    return {
      if (_state.startedAt != null)
        'usage_started_at': _state.startedAt!.toUtc().toIso8601String(),
      if (_state.lastDay != null) ...{
        'streak_count': _state.count,
        'streak_last_date': StreakSnapshot.dayKey(_state.lastDay),
      },
    };
  }

  /// The increase recorded by the last [recordToday], handed out once.
  StreakIncrease? takeIncrease() {
    final value = _pendingIncrease;
    _pendingIncrease = null;
    return value;
  }

  /// Called after a successful sync that sent the streak at [sentRevision].
  /// Returns true when a newer change still has to be sent.
  Future<bool> markSynced(int sentRevision) async {
    await ensureLoaded();
    if (_revision == sentRevision) await _setUnsynced(false);
    return _unsynced;
  }

  /// Forgets memory so the next load re-reads prefs.
  void resetCache() {
    _state = const StreakSnapshot();
    _loaded = false;
    _loader = null;
    _unsynced = true;
    _revision = 0;
    _pendingIncrease = null;
    notifyListeners();
  }

  Future<void> _setUnsynced(bool value) async {
    _unsynced = value;
    final prefs = await AppPrefs.instance;
    await prefs.setBool(unsyncedKey, value);
  }

  Future<void> _load() async {
    final prefs = await AppPrefs.instance;
    final started = DateTime.tryParse(prefs.getString(startedKey) ?? '');
    _state = StreakSnapshot(
      count: prefs.getInt(countKey) ?? 0,
      lastDay: StreakSnapshot.parseDayKey(prefs.getString(lastDayKey)),
      startedAt: started?.toLocal(),
    );
    // Missing on installs from before this flag: send the streak once.
    _unsynced = prefs.getBool(unsyncedKey) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist({required bool markDirty}) async {
    final prefs = await AppPrefs.instance;
    await prefs.setInt(countKey, _state.count);
    final day = StreakSnapshot.dayKey(_state.lastDay);
    if (day == null) {
      await prefs.remove(lastDayKey);
    } else {
      await prefs.setString(lastDayKey, day);
    }
    final started = _state.startedAt;
    if (started == null) {
      await prefs.remove(startedKey);
    } else {
      await prefs.setString(startedKey, started.toUtc().toIso8601String());
    }
    await prefs.setBool(unsyncedKey, _unsynced);
    if (markDirty) {
      await SyncDirty.mark(settings: true);
    }
  }
}
