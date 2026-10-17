// In-app notifications: the stored feed, mute, and the engine that turns
// ledger changes into alerts.
//
// Parts: notification_rules.dart (one rule per alert kind) and
// notification_snapshot.dart (the last-seen figures alerts compare
// against). Grouping for the list lives in notification_time_group.dart,
// re-exported here.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:waffr/core/insights/smart/arabic_text.dart';
import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/sync/sync_mapper.dart';
import 'package:waffr/core/sync/sync_merge.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/data/models/app_notification.dart';
import 'package:waffr/data/models/calendar_period.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/services/smart_settings.dart';
import 'package:waffr/data/services/system_notifications.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/stores/transaction_store.dart';

export 'package:waffr/data/services/notification_time_group.dart';

part 'notification_rules.dart';
part 'notification_snapshot.dart';

/// In-app notification engine for balance, spending, goals, savings, and periods.
///
/// Storage (AppPrefs): encoded [AppNotification] list, mute flag, dedupe
/// [eventKey] set, and a [_NotificationSnapshot] of last-known ratios and IDs.
/// Evaluation runs after [TransactionStore] changes ([listen] → [evaluate]), or
/// via [seedIfNeeded] / [evaluate]; screens only display the feed—do not call
/// from `build()`. Alerts fire when values cross thresholds vs the snapshot,
/// not on every load. Thresholds ([NotificationThresholds]): remaining balance
/// 25/10%; spending 50%; goals 50/75%; large expense = 2× prior average once
/// there are more than four expenses (scheduled bills excluded). Every message
/// names the amount or goal it is about.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  /// The app-wide service.
  static final NotificationService instance = NotificationService._();

  static const String _itemsKey = 'waffer_notifications';

  static const String _mutedKey = 'waffer_notifications_muted';

  static const String _eventKeysKey = 'waffer_notification_event_keys';

  static const String _snapshotKey = 'waffer_notification_snapshot';

  final List<AppNotification> _items = [];

  final Set<String> _eventKeys = {};

  _NotificationSnapshot _snapshot = _NotificationSnapshot.empty();

  Future<void>? _loader;

  bool _loaded = false;

  bool _muted = false;

  bool _listening = false;

  bool _evaluating = false;

  /// True once loaded from prefs.
  bool get isLoaded => _loaded;

  /// True when new alerts are not written to the feed.
  bool get isMuted => _muted;

  /// Notifications not opened yet.
  int get unreadCount => _items.where((item) => !item.isRead).length;

  /// The feed, newest first.
  List<AppNotification> get notifications => List.unmodifiable(_items);

  /// Loads from prefs once; later calls return the same future.
  Future<void> ensureLoaded() => _loader ??= _load();

  /// Subscribes to [TransactionStore] so each change schedules [evaluate].
  void listen() {
    if (_listening) return;
    _listening = true;
    TransactionStore.instance.addListener(_onStoreChanged);
  }

  /// Captures the first store baseline before due periods are processed.
  Future<void> seedIfNeeded() async {
    await ensureLoaded();
    if (_snapshot.initialized) return;

    _applyBaseline(TransactionStore.instance);
    await _persist();
    notifyListeners();
  }

  /// Compares current store state to the snapshot and emits new alerts.
  Future<void> evaluate() async {
    if (_evaluating) return;
    _evaluating = true;

    try {
      await ensureLoaded();
      final store = TransactionStore.instance;
      await store.ensureLoaded();
      await SmartSettings.instance.ensureLoaded();

      if (!_snapshot.initialized) {
        _applyBaseline(store);
        await _persist();
        notifyListeners();
        return;
      }

      var changed = false;
      changed |= _evaluateBalance(store);
      changed |= _evaluateSpending(store);
      changed |= _evaluateGoals(store);
      changed |= _evaluateTransfers(store);
      changed |= _evaluatePeriods(store);
      changed |= _evaluateLargeExpenses(store);
      changed |= _evaluateForecast(store);

      final previous = _snapshot;
      _refreshSnapshot(store);

      if (changed) {
        await _persist();
        notifyListeners();
      } else if (!_snapshot.sameAs(previous)) {
        await _persistSnapshot();
      }
    } finally {
      _evaluating = false;
    }
  }

  /// Public entry for future features; respects mute and event-key dedupe.
  Future<bool> add({
    required NotificationType type,
    required String title,
    required String message,
    required String eventKey,
    String? relatedId,
    Map<String, String> metadata = const {},
    DateTime? createdAt,
  }) async {
    await ensureLoaded();
    final created = _tryAdd(
      type: type,
      title: title,
      message: message,
      eventKey: eventKey,
      relatedId: relatedId,
      metadata: metadata,
      createdAt: createdAt,
    );
    if (!created) return false;
    await _persist();
    notifyListeners();
    return true;
  }

  /// Persists mute state and marks settings dirty for sync.
  Future<void> setMuted(bool muted) async {
    await ensureLoaded();
    if (_muted == muted) return;
    _muted = muted;
    final prefs = await AppPrefs.instance;
    await prefs.setBool(_mutedKey, muted);
    await SyncDirty.mark(settings: true);
    notifyListeners();
    unawaited(
      SystemNotifications.instance.syncStreakReminder(
        enabled: !muted && UsageStreakService.instance.count >= 2,
        streakCount: UsageStreakService.instance.count,
      ),
    );
  }

  /// Flips [isMuted].
  Future<void> toggleMuted() => setMuted(!_muted);

  /// Marks a single notification read and saves the list.
  Future<void> markRead(String id) async {
    await ensureLoaded();
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || _items[index].isRead) return;
    _items[index] = _items[index].copyWith(isRead: true);
    await _persistItems();
    notifyListeners();
  }

  /// Marks every unread item read in one persist.
  Future<void> markAllRead() async {
    await ensureLoaded();
    if (_items.every((item) => item.isRead)) return;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(isRead: true);
      }
    }
    await _persistItems();
    notifyListeners();
  }

  /// Deletes one notification. The list updates before the save so a
  /// swiped-away tile leaves the screen in the same frame.
  Future<void> remove(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _items.removeAt(index);
    notifyListeners();
    await SyncTombstones.instance.add(SyncCollection.notifications, id);
    await _persistItems();
  }

  /// Clears the feed only; leaves balance, savings, goals, and mute untouched.
  Future<void> clearHistory() async {
    await ensureLoaded();
    if (_items.isEmpty) return;
    await SyncTombstones.instance.addMany(
      SyncCollection.notifications,
      _items.map((item) => item.id),
    );
    _items.clear();
    await _persistItems();
    notifyListeners();
  }

  /// Merges remote notification upserts/deletes and optional mute into local state.
  Future<void> applyRemoteSync({
    required List<Map<String, dynamic>> upserts,
    required List<SyncTombstone> deletes,
    bool? muted,
  }) async {
    await ensureLoaded();

    var changed = mergeRemoteRecords<AppNotification>(
      items: _items,
      upserts: [
        for (final raw in upserts)
          if (notificationFromSync(raw) != null) notificationFromSync(raw)!,
      ],
      deletes: deletes,
      collection: SyncCollection.notifications,
      idOf: (item) => item.id,
      updatedOf: (item) => item.syncUpdatedAt,
    );

    for (final item in _items) {
      _eventKeys.add(item.eventKey);
    }

    if (muted != null && muted != _muted) {
      _muted = muted;
      changed = true;
    }

    if (!changed) return;

    _sort();
    await _persist();
    notifyListeners();
  }

  /// Drops in-memory state after a full local data wipe.
  void resetCache() {
    _items.clear();
    _eventKeys.clear();
    _snapshot = _NotificationSnapshot.empty();
    _muted = false;
    _loaded = false;
    _loader = null;
    notifyListeners();
  }

  // Store changes come in bursts (an add, then its sync echo, then the
  // currency store). Evaluate once after they settle, and after the sheet
  // close and number animations, instead of on every notification.
  Timer? _evaluateTimer;

  void _onStoreChanged() {
    _evaluateTimer?.cancel();
    _evaluateTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(evaluate());
    });
  }

  /// Loads items, event keys, mute, and snapshot from AppPrefs.
  Future<void> _load() async {
    final prefs = await AppPrefs.instance;

    _items
      ..clear()
      ..addAll(
        (prefs.getStringList(_itemsKey) ?? const [])
            .map(AppNotification.decode)
            .whereType<AppNotification>(),
      );
    _sort();

    _eventKeys
      ..clear()
      ..addAll(prefs.getStringList(_eventKeysKey) ?? const []);

    for (final item in _items) {
      _eventKeys.add(item.eventKey);
    }

    _muted = prefs.getBool(_mutedKey) ?? false;
    _snapshot = _NotificationSnapshot.decode(prefs.getString(_snapshotKey));
    _loaded = true;
    notifyListeners();
  }

  /// Dedupes by [eventKey]; when muted, keys are still claimed so events stay quiet.
  bool _tryAdd({
    required NotificationType type,
    required String title,
    required String message,
    required String eventKey,
    String? relatedId,
    Map<String, String> metadata = const {},
    DateTime? createdAt,
  }) {
    if (_eventKeys.contains(eventKey)) return false;
    _eventKeys.add(eventKey);

    if (_muted) return false;

    _items.add(
      AppNotification(
        id: AppNotification.newId(),
        type: type,
        title: title,
        message: message,
        createdAt: (createdAt ?? deviceNow()).toLocal(),
        eventKey: eventKey,
        relatedId: relatedId,
        metadata: metadata,
      ),
    );
    _sort();
    unawaited(
      SystemNotifications.instance.present(
        eventKey: eventKey,
        title: title,
        body: message,
      ),
    );
    return true;
  }

  void _sort() {
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Writes items, event keys, mute, and snapshot; marks sync dirty.
  Future<void> _persist() async {
    final prefs = await AppPrefs.instance;
    await prefs.setStringList(
      _itemsKey,
      _items.map((item) => item.encode()).toList(),
    );
    await prefs.setStringList(_eventKeysKey, _eventKeys.toList());
    await prefs.setBool(_mutedKey, _muted);
    await prefs.setString(_snapshotKey, _snapshot.encode());
    await SyncDirty.mark();
  }

  Future<void> _persistItems() async {
    final prefs = await AppPrefs.instance;
    await prefs.setStringList(
      _itemsKey,
      _items.map((item) => item.encode()).toList(),
    );
    await SyncDirty.mark();
  }

  Future<void> _persistSnapshot() async {
    final prefs = await AppPrefs.instance;
    await prefs.setStringList(_eventKeysKey, _eventKeys.toList());
    await prefs.setString(_snapshotKey, _snapshot.encode());
  }
}
