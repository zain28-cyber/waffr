// The balance cycle: when it started, what was spent in it, and its 100%
// (maxBalance) that the home bar and the balance alerts measure against.

part of 'transaction_store.dart';

/// The balance cycle: the 100% the home bar measures against.
///
/// A new cycle starts when income arrives on an empty balance (all of it
/// spent, or the leftover just moved to savings), and at the start of every
/// month when the income is monthly.
extension BalanceCycle on TransactionStore {
  // Balances this close to zero count as empty (rounding).
  static const double _cycleEpsilon = 0.005;

  bool _isCarryOver(WaffrTransaction item) =>
      item.isSavingsIn &&
      (item.processedPeriodKey == TransactionStore.carryOverKey ||
          (item.transferKind == SavingsTransferKind.manual &&
              item.note == TransactionStore._carryOverNote));

  // Transfers that close a cycle rather than spend from it.
  bool _closesCycle(WaffrTransaction item) =>
      _isCarryOver(item) ||
      (item.isSavingsIn &&
          item.transferKind == SavingsTransferKind.periodLeftover);

  /// Start of the current balance cycle, or null before the first reset.
  ///
  /// A new cycle starts when income arrives on an empty balance (all of it
  /// spent, or the leftover just moved to savings), and at the start of
  /// every month when the income is monthly.
  DateTime? cycleStartFor(String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    // Monthly income also restarts the cycle on the 1st, so the month and
    // the income frequency are part of the cache key.
    final key =
        '$code|${preferredIncomeFrequencyFor(code).name}|'
        '${CalendarPeriod.monthStart(deviceNow()).millisecondsSinceEpoch}';
    if (_cycleStarts.containsKey(key)) return _cycleStarts[key];
    return _cycleStarts[key] = _computeCycleStart(code);
  }

  DateTime? _computeCycleStart(String code) {
    final rows =
        _transactions.where((item) => item.currencyCode == code).toList()
          ..sort((a, b) {
            final byTime = a.dateTime.compareTo(b.dateTime);
            if (byTime != 0) return byTime;
            // Same moment: the carry-over transfer comes before its income.
            return (a.isIncome ? 1 : 0).compareTo(b.isIncome ? 1 : 0);
          });

    DateTime? start;
    var running = 0.0;
    var saved = 0.0;
    for (final item in rows) {
      if (item.isIncome && running <= _cycleEpsilon) start = item.dateTime;
      if (item.isIncome) running += item.amount;
      if (item.isExpense) running -= item.amount;
      if (item.isSavingsIn) {
        running -= item.amount;
        saved += item.amount;
      }
      if (item.isSavingsOut) {
        // Withdrawals return at most what is in savings, like balanceFor.
        final back = item.amount < saved ? item.amount : saved;
        running += back;
        saved -= back;
      }
      if (_isCarryOver(item) &&
          (start == null || item.dateTime.isAfter(start))) {
        start = item.dateTime;
      }
    }

    if (preferredIncomeFrequencyFor(code) == RecurringFrequency.monthly) {
      final monthStart = CalendarPeriod.monthStart(deviceNow());
      if (start == null || monthStart.isAfter(start)) start = monthStart;
    }
    return start;
  }

  bool _inCycle(WaffrTransaction item, DateTime? start) =>
      start == null || !item.dateTime.isBefore(start);

  /// Expenses recorded in the current cycle.
  double cycleSpentFor(String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    final start = cycleStartFor(code);
    var total = 0.0;
    for (final item in _transactions) {
      if (item.currencyCode == code &&
          item.isExpense &&
          _inCycle(item, start)) {
        total += item.amount;
      }
    }
    return total;
  }

  /// [cycleSpentFor] the active currency.
  double get cycleSpent => cycleSpentFor(_activeCode);

  /// The cycle's 100%: what the balance would be now if nothing had been
  /// spent or saved since the cycle started.
  double get maxBalance => maxBalanceFor(_activeCode);

  /// The cycle's 100% in [currencyCode]: what the balance would be if
  /// nothing had been spent or saved since the cycle started.
  double maxBalanceFor(String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    final start = cycleStartFor(code);
    return _maxBalances[(code, start)] ??= _computeMaxBalance(code, start);
  }

  double _computeMaxBalance(String code, DateTime? start) {
    var used = 0.0;
    for (final item in _transactions) {
      if (item.currencyCode != code || !_inCycle(item, start)) continue;
      if (_closesCycle(item)) continue;
      if (item.isExpense || item.isSavingsIn) used += item.amount;
      if (item.isSavingsOut) used -= item.amount;
    }
    final capacity = balanceFor(code) + used;
    return capacity > 0 ? capacity : 0;
  }

  /// Stable id of the current cycle, for one-alert-per-cycle notifications.
  String get cycleKey => cycleKeyFor(_activeCode);

  /// A stable id of the current cycle in [currencyCode].
  String cycleKeyFor(String currencyCode) {
    final start = cycleStartFor(currencyCode);
    return '${start?.millisecondsSinceEpoch ?? 0}';
  }

  /// [remainingRatioFor] the active currency.
  double get remainingRatio => remainingRatioFor(_activeCode);

  /// Balance left as a share of [maxBalanceFor], 0..1.
  double remainingRatioFor(String currencyCode) {
    final max = maxBalanceFor(currencyCode);

    if (max <= 0) {
      return 0;
    }

    return (balanceFor(currencyCode) / max).clamp(0.0, 1.0);
  }
}
