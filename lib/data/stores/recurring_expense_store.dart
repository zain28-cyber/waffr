// Recurring expenses: CRUD, sync, and due-date catch-up that posts real expenses.

import 'package:flutter/foundation.dart';
import 'package:waffr/data/models/app_notification.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/sync/sync_mapper.dart';
import 'package:waffr/core/sync/sync_merge.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/insights/smart/arabic_text.dart';

/// Schedules checked on launch/resume; posts expenses when nextDueAt is past.
class RecurringExpenseStore extends ChangeNotifier {
  RecurringExpenseStore._();

  /// The app-wide schedule store.
  static final RecurringExpenseStore instance = RecurringExpenseStore._();

  /// Prefs key of the schedules (one JSON string each).
  static const String itemsKey = 'recurring_expenses';

  static const int _maxCatchUp = 24;

  final List<RecurringExpense> _items = [];

  Future<void>? _loader;
  bool _loaded = false;
  Future<void>? _dueTail;

  /// True once loaded from prefs.
  bool get isLoaded => _loaded;

  /// Every schedule, newest first.
  List<RecurringExpense> get items => List.unmodifiable(_items);

  /// Schedules in [currencyCode], newest first.
  List<RecurringExpense> itemsFor(String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    return _items
        .where((item) => item.currencyCode == code)
        .toList(growable: false);
  }

  /// Loads from prefs once; later calls return the same future.
  Future<void> ensureLoaded() => _loader ??= _load();

  /// The schedule with [id], if any.
  RecurringExpense? byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// With [requiresConfirmation] the first charge waits for the user's approval.
  Future<void> addExpense({
    required double amount,
    required String category,
    required String paymentMethod,
    required RecurringUnit unit,
    required int intervalCount,
    String? note,
    String? currencyCode,
    bool requiresConfirmation = false,
  }) async {
    if (amount <= 0 || intervalCount <= 0) return;

    await ensureLoaded();
    await TransactionStore.instance.ensureLoaded();
    final code = Currencies.normalize(
      currencyCode ?? CurrencyStore.instance.activeCode,
    );

    final now = deviceNow();

    _items.insert(
      0,
      RecurringExpense(
        id: RecurringExpense.newId(),
        amount: amount,
        currencyCode: code,
        category: category,
        paymentMethod: paymentMethod,
        note: note,
        unit: unit,
        intervalCount: intervalCount,
        createdAt: now,
        // Due immediately so the first charge is written to history now (or
        // listed for approval). Later charges wait until this date.
        nextDueAt: now,
        requiresConfirmation: requiresConfirmation,
      ),
    );

    await _persist();
    notifyListeners();
    await processDue();
  }

  static const double _maxAmount = 999999999;

  /// Changes a schedule's amount (and currency); false when invalid.
  Future<bool> updateAmount(
    String id,
    double amount, {
    String? currencyCode,
  }) async {
    if (!amount.isFinite || amount <= 0 || amount > _maxAmount) {
      return false;
    }

    await ensureLoaded();

    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return false;

    _items[index] = _items[index].copyWith(
      amount: amount,
      currencyCode: currencyCode,
    );
    await _persist();
    notifyListeners();
    return true;
  }

  /// Pauses or resumes a schedule.
  Future<void> setEnabled(String id, bool enabled) async {
    await ensureLoaded();

    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;

    _items[index] = _items[index].copyWith(enabled: enabled);
    await _persist();
    notifyListeners();
  }

  /// Switches between automatic and approved charges; switching to
  /// automatic posts what is due right away.
  Future<void> setRequiresConfirmation(String id, bool value) async {
    await ensureLoaded();

    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || _items[index].requiresConfirmation == value) return;

    _items[index] = _items[index].copyWith(
      requiresConfirmation: value,
      clearReminder: true,
    );
    await _persist();
    notifyListeners();
    if (!value) await processDue();
  }

  /// Charges that wait for the user's approval, oldest schedule first.
  List<RecurringExpense> awaitingConfirmation(
    String currencyCode, {
    DateTime? now,
  }) {
    final moment = now ?? deviceNow();
    final list = itemsFor(currencyCode)
        .where(
          (item) =>
              item.enabled &&
              item.requiresConfirmation &&
              item.dueDates(moment, max: 1).isNotEmpty,
        )
        .toList();
    list.sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    return list;
  }

  /// Charges not yet posted: approvals pending plus automatic ones held back
  /// by a low balance.
  int overdueCount(String currencyCode, {DateTime? now}) {
    final moment = now ?? deviceNow();
    var count = 0;
    for (final item in itemsFor(currencyCode)) {
      if (!item.enabled) continue;
      count += item.dueDates(moment).length;
    }
    return count;
  }

  /// Monthly cost of all active schedules in a currency.
  double monthlyTotal(String currencyCode) {
    var total = 0.0;
    for (final item in itemsFor(currencyCode)) {
      if (item.enabled) total += item.monthlyEquivalent;
    }
    return total;
  }

  /// Next charge date among active schedules in a currency.
  RecurringExpense? nextUpcoming(String currencyCode, {DateTime? now}) {
    final moment = now ?? deviceNow();
    RecurringExpense? next;
    for (final item in itemsFor(currencyCode)) {
      if (!item.enabled || !item.nextDueAt.isAfter(moment)) continue;
      if (next == null || item.nextDueAt.isBefore(next.nextDueAt)) {
        next = item;
      }
    }
    return next;
  }

  /// Posts the oldest pending charge, or every pending one with [all].
  /// Returns how many were posted; stops early when the balance runs out.
  Future<int> confirmDue(String id, {bool all = false}) {
    final previous = _dueTail ?? Future<void>.value();
    final run = previous
        .catchError((Object _) {})
        .then((_) => _confirmDue(id, all: all));
    _dueTail = run;
    return run;
  }

  Future<int> _confirmDue(String id, {required bool all}) async {
    await ensureLoaded();
    await TransactionStore.instance.ensureLoaded();

    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return 0;

    final now = deviceNow();
    var item = _items[index];
    // Post the oldest due charge (or all of them), stopping when the balance
    // runs out; charges already in the history only move the schedule on.
    final dates = item.dueDates(now);
    final wanted = all ? dates : dates.take(1);
    var posted = 0;

    for (final dueAt in wanted) {
      final store = TransactionStore.instance;
      final sourceId = _sourceId(item.id, dueAt);
      if (!_alreadyPosted(sourceId)) {
        if (!store.canDeduct(item.amount, currencyCode: item.currencyCode)) {
          break;
        }
        final added = await _postCharge(item, dueAt);
        if (added == null) break;
      }
      posted++;
      item = _advancedPast(item, dueAt);
    }

    // Nothing left due: any postponement is over.
    if (posted == 0) return 0;

    if (item.dueDates(now, max: 1).isEmpty) {
      item = item.copyWith(clearReminder: true);
    }
    _items[index] = item;
    await _persist();
    notifyListeners();
    return posted;
  }

  /// Keeps the charge pending and reminds after [after], or on the next income.
  Future<void> postpone(
    String id, {
    Duration? after,
    bool untilIncome = false,
  }) async {
    await ensureLoaded();

    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;

    _items[index] = untilIncome
        ? _items[index]
              .copyWith(clearReminder: true)
              .copyWith(remindOnIncome: true)
        : _items[index]
              .copyWith(clearReminder: true)
              .copyWith(
                remindAt: deviceNow().add(after ?? const Duration(days: 1)),
              );
    await _persist();
    notifyListeners();
  }

  /// New income ends "remind me on next income" postponements in that currency.
  Future<void> releaseIncomeReminders(String currencyCode) async {
    await ensureLoaded();

    final code = Currencies.normalize(currencyCode);
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.currencyCode != code || !item.remindOnIncome) continue;
      _items[i] = item.copyWith(clearReminder: true);
      changed = true;
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  /// Deletes a schedule and logs the delete for sync. Charges already
  /// posted stay in the history.
  Future<void> deleteExpense(String id) async {
    await ensureLoaded();

    final before = _items.length;
    _items.removeWhere((item) => item.id == id);
    if (_items.length == before) return;

    await SyncTombstones.instance.add(SyncCollection.recurringExpenses, id);
    await _persist();
    notifyListeners();
  }

  /// Deducts due items when balance allows; otherwise notifies and stops catch-up.
  /// Calls are queued so opening the app twice cannot post the same period twice.
  Future<void> processDue() {
    final previous = _dueTail ?? Future<void>.value();
    final run = previous.catchError((Object _) {}).then((_) => _processDue());
    _dueTail = run;
    return run;
  }

  Future<void> _processDue() async {
    await ensureLoaded();
    await TransactionStore.instance.ensureLoaded();

    final now = deviceNow();
    var changed = false;

    for (var i = 0; i < _items.length; i++) {
      var item = _items[i];
      if (!item.enabled) continue;

      // Charges that need approval are only reminded about, never posted.
      if (item.requiresConfirmation) {
        if (await _remindAwaiting(item, now)) {
          _items[i] = item.copyWith(clearReminder: true);
          changed = true;
        }
        continue;
      }

      // Schedules saved before the first charge was due never reached history.
      if (item.nextDueAt.isAfter(now) && !_hasPosted(item.id)) {
        item = item.copyWith(nextDueAt: now);
        _items[i] = item;
        changed = true;
      }

      // Post every missed charge in order (at most 24), saving after each, and
      // stop at the first one the balance cannot cover.
      var catchUps = 0;
      DateTime? postedDue;

      while (_isDue(item.nextDueAt, now) && catchUps < _maxCatchUp) {
        catchUps++;

        final store = TransactionStore.instance;
        final dueAt = item.nextDueAt;
        final sourceId = _sourceId(item.id, dueAt);

        if (!store.canDeduct(item.amount, currencyCode: item.currencyCode) &&
            !_alreadyPosted(sourceId)) {
          await _notifyBlocked(item, dueAt);
          break;
        }

        final added = await _postCharge(item, dueAt);

        if (added == null) {
          await _notifyBlocked(item, dueAt);
          break;
        }

        postedDue = dueAt;
        item = _advancedPast(item, dueAt);
        _items[i] = item;
        changed = true;
        await _persist();
      }

      // One notice per schedule for what was posted in this pass.
      if (postedDue != null) {
        await _notifyApplied(item, postedDue);
      }
    }

    if (changed) {
      await _persist();
      notifyListeners();
    }

    // Finally, warn about charges in the next two days the balance lacks.
    await _warnUpcomingShortfalls(now);
  }

  // One heads-up per charge when the next scheduled amount, due within two
  // days, is more than the balance in that currency.
  Future<void> _warnUpcomingShortfalls(DateTime now) async {
    final store = TransactionStore.instance;
    final horizon = now.add(const Duration(days: 2));
    for (final item in _items) {
      if (!item.enabled) continue;
      final due = item.nextDueAt;
      if (!due.isAfter(now) || due.isAfter(horizon)) continue;
      if (store.canDeduct(item.amount, currencyCode: item.currencyCode)) {
        continue;
      }
      final symbol = currencyLabelFor(item.currencyCode);
      try {
        await NotificationService.instance.add(
          type: NotificationType.recurringExpenseUpcoming,
          title: 'رصيدك لا يكفي لمصروف قادم',
          message:
              '${_labelOf(item)}: يُخصم ${formatMoney(item.amount)} $symbol في ${formatDate(due)}، '
              'ورصيدك الآن ${formatMoney(store.balanceFor(item.currencyCode))} $symbol.',
          eventKey: 'recurringUpcoming:${item.id}:${due.toIso8601String()}',
          relatedId: item.id,
        );
      } catch (error, stack) {
        debugPrint('Recurring upcoming notice failed: $error\n$stack');
      }
    }
  }

  // Notifies about a charge waiting for approval. Returns true when an expired
  // reminder date should be cleared from the schedule.
  Future<bool> _remindAwaiting(RecurringExpense item, DateTime now) async {
    final dates = item.dueDates(now);
    if (dates.isEmpty || item.remindOnIncome) return false;

    final remindAt = item.remindAt;
    if (remindAt != null && remindAt.isAfter(now)) return false;

    // The first charge of a schedule just added is shown on the home screen.
    final justAdded =
        dates.length == 1 &&
        !_hasPosted(item.id) &&
        now.difference(item.createdAt).inMinutes < 5;
    if (!justAdded) {
      final key = remindAt == null
          ? 'recurringDue:${item.id}:${dates.last.toIso8601String()}'
          : 'recurringDue:${item.id}:remind:${remindAt.toIso8601String()}';
      final symbol = currencyLabelFor(item.currencyCode);
      final count = dates.length;
      try {
        await NotificationService.instance.add(
          type: NotificationType.recurringExpenseDue,
          title: 'حان موعد ${_labelOf(item)}',
          message: count > 1
              ? 'لديك ${Ar.payments.of(count)} مستحقة بقيمة ${formatMoney(item.amount)} $symbol لكل دفعة. افتح الالتزامات لتأكيد الخصم أو تأجيله.'
              : 'المبلغ ${formatMoney(item.amount)} $symbol. افتح الالتزامات لتأكيد الخصم أو تأجيله.',
          eventKey: key,
          relatedId: item.id,
        );
      } catch (error, stack) {
        debugPrint('Recurring due notice failed: $error\n$stack');
      }
    }
    return remindAt != null;
  }

  // Posts the charge of [item] due at [dueAt] as an expense dated then;
  // null when the balance cannot cover it.
  Future<WaffrTransaction?> _postCharge(RecurringExpense item, DateTime dueAt) {
    return TransactionStore.instance.addExpense(
      amount: item.amount,
      category: item.category,
      paymentMethod: item.paymentMethod,
      note: item.note ?? item.intervalDescription,
      sourceId: _sourceId(item.id, dueAt),
      occurredAt: dueAt.toLocal(),
      currencyCode: item.currencyCode,
    );
  }

  // [item] with its next charge moved one step past [dueAt].
  RecurringExpense _advancedPast(RecurringExpense item, DateTime dueAt) {
    return item.copyWith(
      nextDueAt: RecurringExpense.nextDueFrom(
        dueAt,
        item.unit,
        item.intervalCount,
      ),
    );
  }

  bool _isDue(DateTime due, DateTime now) => !due.toUtc().isAfter(now.toUtc());

  // Stable for a given local minute so a reload cannot mint a second source id.
  String _sourceId(String id, DateTime due) {
    final local = due.toLocal();
    final stamp =
        '${local.year.toString().padLeft(4, '0')}'
        '${local.month.toString().padLeft(2, '0')}'
        '${local.day.toString().padLeft(2, '0')}'
        '${local.hour.toString().padLeft(2, '0')}'
        '${local.minute.toString().padLeft(2, '0')}';
    return '${RecurringExpense.sourcePrefix}$id:$stamp';
  }

  bool _alreadyPosted(String sourceId) {
    for (final item in TransactionStore.instance.transactions) {
      if (item.isExpense && item.sourceId == sourceId) return true;
    }
    return false;
  }

  bool _hasPosted(String id) {
    final prefix = '${RecurringExpense.sourcePrefix}$id:';
    for (final item in TransactionStore.instance.transactions) {
      final source = item.sourceId;
      if (item.isExpense && source != null && source.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  // Name used in notices, in «» quotes: the note, else the category.
  String _labelOf(RecurringExpense item) {
    final note = item.note?.trim() ?? '';
    return Ar.quote(note.isEmpty ? item.category : note);
  }

  Future<void> _notifyBlocked(RecurringExpense item, DateTime dueAt) async {
    try {
      await NotificationService.instance.add(
        type: NotificationType.recurringExpenseBlocked,
        title: 'تعذّر خصم ${_labelOf(item)}',
        message:
            'رصيدك لا يكفي لخصم ${formatMoney(item.amount)} ${currencyLabelFor(item.currencyCode)}. '
            'سيُخصم تلقائياً عندما يتوفر الرصيد.',
        eventKey: 'recurringBlocked:${item.id}:${dueAt.toIso8601String()}',
        relatedId: item.id,
      );
    } catch (error, stack) {
      debugPrint('Recurring block notice failed: $error\n$stack');
    }
  }

  Future<void> _notifyApplied(RecurringExpense item, DateTime postedDue) async {
    try {
      await NotificationService.instance.add(
        type: NotificationType.recurringExpenseApplied,
        title: 'خُصم ${_labelOf(item)}',
        message:
            'خُصم ${formatMoney(item.amount)} ${currencyLabelFor(item.currencyCode)} '
            '(${item.intervalDescription}). الخصم التالي في ${formatDate(item.nextDueAt)}.',
        eventKey: 'recurringApplied:${item.id}:${postedDue.toIso8601String()}',
        relatedId: item.id,
      );
    } catch (error, stack) {
      debugPrint('Recurring applied notice failed: $error\n$stack');
    }
  }

  /// Merges the server's schedules.
  Future<void> applyRemoteSync({
    required List<Map<String, dynamic>> upserts,
    required List<SyncTombstone> deletes,
  }) async {
    await ensureLoaded();

    final changed = mergeRemoteRecords<RecurringExpense>(
      items: _items,
      upserts: [
        for (final raw in upserts)
          if (recurringFromSync(raw) != null) recurringFromSync(raw)!,
      ],
      deletes: deletes,
      collection: SyncCollection.recurringExpenses,
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
      ..addAll(
        stored.map(RecurringExpense.decode).whereType<RecurringExpense>(),
      )
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _loaded = true;
    if (stored.any((raw) => !raw.contains('currencyCode'))) {
      await _persist();
    }
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
}
