// Merges the server's rows and settings into the ledger after a sync.

part of 'transaction_store.dart';

/// Merging the server's copy into the ledger after a sync.
extension LedgerSync on TransactionStore {
  /// Merges the server's transactions, transfers and goals (upserts and
  /// deletes), and settings that are newer than the local ones.
  Future<void> applyRemoteSync({
    required List<Map<String, dynamic>> transactions,
    required List<SyncTombstone> transactionDeletes,
    required List<Map<String, dynamic>> transfers,
    required List<SyncTombstone> transferDeletes,
    required List<Map<String, dynamic>> goals,
    required List<SyncTombstone> goalDeletes,
    Map<String, dynamic>? settings,
  }) async {
    await ensureLoaded();

    // Rows: incomes/expenses, then savings moves, then goals.
    var changed = mergeRemoteRecords<WaffrTransaction>(
      items: _transactions,
      upserts: [
        for (final raw in transactions)
          if (transactionFromSync(raw) != null)
            _preserveEventTime(transactionFromSync(raw)!),
      ],
      deletes: transactionDeletes,
      collection: SyncCollection.transactions,
      idOf: (item) => item.id,
      updatedOf: (item) => item.syncUpdatedAt,
    );

    changed |= mergeRemoteRecords<WaffrTransaction>(
      items: _transactions,
      upserts: [
        for (final raw in transfers)
          if (transferFromSync(raw) != null)
            _preserveEventTime(transferFromSync(raw)!),
      ],
      deletes: transferDeletes,
      collection: SyncCollection.savingsTransfers,
      idOf: (item) => item.id,
      updatedOf: (item) => item.syncUpdatedAt,
    );

    changed |= mergeRemoteRecords<SavingsGoal>(
      items: _goals,
      upserts: [
        for (final raw in goals)
          if (goalFromSync(raw) != null) goalFromSync(raw)!,
      ],
      deletes: goalDeletes,
      collection: SyncCollection.savingsGoals,
      idOf: (item) => item.id,
      updatedOf: (item) => item.syncUpdatedAt,
    );

    // Settings: processed periods are a union; the rest replaces local
    // values only when the server copy is at least as new.
    if (settings != null) {
      final keys = settings['processed_period_keys'];
      if (keys is List) {
        final before = _processedPeriods.length;
        _processedPeriods.addAll(keys.map((item) => item.toString()));
        if (_processedPeriods.length != before) changed = true;
      }

      final remoteUpdated = parseSyncDate(settings['updated_at']);
      final localUpdated = await SyncDirty.settingsUpdatedAt();
      if (newerOrEqual(remoteUpdated, localUpdated)) {
        if (settings.containsKey('monthly_income_amount')) {
          final amount = parseMoney(settings['monthly_income_amount']);
          if (amount != null && amount > 0) {
            _monthlyIncomeByCurrency[defaultCurrencyCode] = amount;
          } else {
            _monthlyIncomeByCurrency.remove(defaultCurrencyCode);
          }
        }
        if (settings.containsKey('weekly_income_amount')) {
          final amount = parseMoney(settings['weekly_income_amount']);
          if (amount != null && amount > 0) {
            _weeklyIncomeByCurrency[defaultCurrencyCode] = amount;
          } else {
            _weeklyIncomeByCurrency.remove(defaultCurrencyCode);
          }
        }
        if (settings.containsKey('income_overrides_by_currency')) {
          _replaceNonDefaultIncomeOverrides(
            settings['income_overrides_by_currency'],
          );
        }
        await CurrencyStore.instance.applyRemote(
          enabled: settings['enabled_currencies'] is List
              ? settings['enabled_currencies'] as List
              : null,
          active: settings['active_currency']?.toString(),
        );
        if (remoteUpdated != null) {
          await SyncDirty.setSettingsUpdatedAt(remoteUpdated);
        }
        changed = true;
        await ProfileSync.apply(settings);
      }
    }

    // Something changed: re-sort, settle goals, save, and tell the screens.
    if (!changed) return;

    _sort();
    _completeGoalIfNeeded();
    final prefs = await AppPrefs.instance;
    await _persistAll(prefs);
    notifyListeners();
  }

  // Keeps the earlier local event time when merging a remote duplicate id.
  WaffrTransaction _preserveEventTime(WaffrTransaction incoming) {
    for (final local in _transactions) {
      if (local.id != incoming.id) continue;
      return incoming.copyWith(
        dateTime: earlierDeviceEventTime(local.dateTime, incoming.dateTime),
      );
    }
    return incoming;
  }
}
