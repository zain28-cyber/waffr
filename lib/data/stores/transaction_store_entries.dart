// Recording and undoing expenses, and manual moves between the balance
// and savings.

part of 'transaction_store.dart';

/// Recording and undoing expenses and moves between balance and savings.
extension LedgerEntries on TransactionStore {
  /// Returns the expense on success, or null when amount exceeds balance.
  Future<WaffrTransaction?> addExpense({
    required double amount,
    required String category,
    required String paymentMethod,
    String? note,
    String? sourceId,
    DateTime? occurredAt,
    String? currencyCode,
  }) async {
    await ensureLoaded();

    final code = Currencies.normalize(currencyCode ?? _activeCode);

    // An automatic expense (bill, purchase) is posted once per source id:
    // return the one already saved, or the one being saved right now.
    if (sourceId != null) {
      for (final item in _transactions) {
        if (item.isExpense && item.sourceId == sourceId) {
          return item;
        }
      }

      final pending = _pendingExpenseSources[sourceId];
      if (pending != null) {
        return pending;
      }
    }

    if (!canDeduct(amount, currencyCode: code)) {
      return null;
    }

    // Remember the in-flight save so a second call with the same source
    // waits for it instead of posting twice.
    final future = _createExpense(
      amount: amount,
      category: category,
      paymentMethod: paymentMethod,
      note: note,
      sourceId: sourceId,
      occurredAt: occurredAt,
      currencyCode: code,
    );

    if (sourceId == null) {
      return future;
    }

    _pendingExpenseSources[sourceId] = future;

    try {
      return await future;
    } finally {
      if (identical(_pendingExpenseSources[sourceId], future)) {
        _pendingExpenseSources.remove(sourceId);
      }
    }
  }

  /// Removes an expense so its amount returns to the operating balance.
  Future<bool> undoExpense(String id) async {
    await ensureLoaded();

    final index = _transactions.indexWhere(
      (item) => item.id == id && item.isExpense,
    );
    if (index < 0) return false;

    _transactions.removeAt(index);
    _touch();
    await SyncTombstones.instance.add(SyncCollection.transactions, id);

    final prefs = await AppPrefs.instance;
    await _persist(prefs);
    notifyListeners();
    return true;
  }

  /// Removes an income row and drops that amount from the balance.
  Future<bool> undoIncome(String id) async {
    await ensureLoaded();

    final index = _transactions.indexWhere(
      (item) => item.id == id && item.isIncome,
    );
    if (index < 0) return false;

    _transactions.removeAt(index);
    _touch();
    await SyncTombstones.instance.add(SyncCollection.transactions, id);

    final prefs = await AppPrefs.instance;
    await _persist(prefs);
    notifyListeners();
    return true;
  }

  /// Manual move from operating balance into savings (tags top active goal).
  Future<bool> saveManually(double amount, {String? currencyCode}) async {
    await ensureLoaded();

    final code = Currencies.normalize(currencyCode ?? _activeCode);
    if (amount <= 0 || amount > balanceFor(code)) {
      return false;
    }

    final currentGoal = activeGoalsFor(code).isEmpty
        ? null
        : activeGoalsFor(code).first;

    await _add(
      WaffrTransaction(
        id: WaffrTransaction.newId(),
        type: TransactionType.savingsIn,
        amount: amount,
        currencyCode: code,
        note: 'توفير يدوي',
        dateTime: deviceNow(),
        transferKind: SavingsTransferKind.manual,
        goalId: currentGoal?.id,
      ),
    );

    return true;
  }

  /// Moves money from savings back to operating balance.
  Future<bool> withdrawFromSavings(
    double amount, {
    String? currencyCode,
  }) async {
    await ensureLoaded();

    final code = Currencies.normalize(currencyCode ?? _activeCode);
    if (amount <= 0 || amount > savingsBalanceFor(code)) {
      return false;
    }

    await _add(
      WaffrTransaction(
        id: WaffrTransaction.newId(),
        type: TransactionType.savingsOut,
        amount: amount,
        currencyCode: code,
        note: 'سحب إلى الرصيد',
        dateTime: deviceNow(),
        transferKind: SavingsTransferKind.withdraw,
      ),
    );

    return true;
  }

  Future<WaffrTransaction?> _createExpense({
    required double amount,
    required String category,
    required String paymentMethod,
    String? note,
    String? sourceId,
    DateTime? occurredAt,
    String? currencyCode,
  }) async {
    final code = Currencies.normalize(currencyCode ?? _activeCode);
    if (!canDeduct(amount, currencyCode: code)) {
      return null;
    }

    final transaction = WaffrTransaction(
      id: WaffrTransaction.newId(),
      type: TransactionType.expense,
      amount: amount,
      currencyCode: code,
      category: category,
      paymentMethod: paymentMethod,
      note: note,
      sourceId: sourceId,
      dateTime: (occurredAt ?? deviceNow()).toLocal(),
    );

    await _add(transaction);
    return transaction;
  }

  Future<void> _add(
    WaffrTransaction transaction, {
    bool persist = true,
    bool notify = true,
  }) async {
    await ensureLoaded();

    _transactions.add(transaction);

    _sort();

    _completeGoalIfNeeded();

    // Screens update first; the disk write follows. Waiting for the write
    // before notifying kept sheets open and balances stale until it ended.
    if (notify) {
      notifyListeners();
    }

    if (persist) {
      final prefs = await AppPrefs.instance;

      await _persistAll(prefs);
    }
  }
}
