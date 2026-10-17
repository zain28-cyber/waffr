// Income: adding an income, the configured weekly/monthly amounts per
// currency (and their JSON form), and the reference income plans use.

part of 'transaction_store.dart';

/// Income: adding it, the configured weekly/monthly amounts per currency,
/// and the figures savings plans are based on.
extension IncomeSettings on TransactionStore {
  /// The configured monthly income in [currencyCode], if any.
  double? monthlyIncomeOverrideFor(String currencyCode) {
    return _monthlyIncomeByCurrency[Currencies.normalize(currencyCode)];
  }

  /// The configured weekly income in [currencyCode], if any.
  double? weeklyIncomeOverrideFor(String currencyCode) {
    return _weeklyIncomeByCurrency[Currencies.normalize(currencyCode)];
  }

  /// Non-SYP configured incomes as JSON for settings sync, or null.
  Object? get incomeOverridesByCurrencyPayload {
    final encoded = _encodeIncomeOverrides();
    if (encoded == null) return null;
    try {
      return jsonDecode(encoded);
    } catch (_) {
      return null;
    }
  }

  /// [hasMonthlyIncomeFor] the active currency.
  bool get hasMonthlyIncome => hasMonthlyIncomeFor(_activeCode);

  /// True when a monthly income is configured or was ever recorded.
  bool hasMonthlyIncomeFor(String currencyCode) {
    final override = monthlyIncomeOverrideFor(currencyCode);
    if (override != null && override > 0) {
      return true;
    }

    return incomesFor(currencyCode)
        .any((item) => item.frequency == RecurringFrequency.monthly);
  }

  /// Settings override only — independent of whether income rows exist.
  bool get hasConfiguredMonthlyIncome =>
      hasConfiguredMonthlyIncomeFor(_activeCode);

  /// True when settings hold a monthly income for [currencyCode].
  bool hasConfiguredMonthlyIncomeFor(String currencyCode) {
    final amount = monthlyIncomeOverrideFor(currencyCode);
    return amount != null && amount > 0;
  }

  /// [configuredMonthlyIncomeFor] the active currency.
  double? get configuredMonthlyIncome =>
      configuredMonthlyIncomeFor(_activeCode);

  /// The configured monthly income in [currencyCode], or null.
  double? configuredMonthlyIncomeFor(String currencyCode) {
    return hasConfiguredMonthlyIncomeFor(currencyCode)
        ? monthlyIncomeOverrideFor(currencyCode)
        : null;
  }

  /// [hasWeeklyIncomeFor] the active currency.
  bool get hasWeeklyIncome => hasWeeklyIncomeFor(_activeCode);

  /// True when a weekly income is configured or was ever recorded.
  bool hasWeeklyIncomeFor(String currencyCode) {
    final override = weeklyIncomeOverrideFor(currencyCode);
    if (override != null && override > 0) {
      return true;
    }

    return incomesFor(currencyCode)
        .any((item) => item.frequency == RecurringFrequency.weekly);
  }

  /// True when the active currency has a weekly or monthly income.
  bool get hasRecurringIncome => hasMonthlyIncome || hasWeeklyIncome;

  /// Income used for plans: settings override, else current/previous period, else calendar sum.
  double referenceIncome(RecurringFrequency frequency, {String? currencyCode}) {
    final code = Currencies.normalize(currencyCode ?? _activeCode);
    final override = _overrideFor(frequency, code);
    if (override != null && override > 0) {
      return override;
    }

    if (frequency == RecurringFrequency.none) {
      return _incomeInCalendar(RecurringFrequency.monthly, deviceNow(), code);
    }

    final now = deviceNow();

    final currentKey = CalendarPeriod.keyFor(frequency, now);

    final current = _incomeForPeriod(frequency, currentKey, code);

    if (current > 0) {
      return current;
    }

    final currentPeriod = CalendarPeriod.ofFrequency(frequency, now);

    final previousStart = frequency == RecurringFrequency.weekly
        ? currentPeriod.start.subtract(const Duration(days: 7))
        : DateTime(currentPeriod.start.year, currentPeriod.start.month - 1);

    final previousKey = CalendarPeriod.keyFor(frequency, previousStart);

    final previous = _incomeForPeriod(frequency, previousKey, code);

    if (previous > 0) {
      return previous;
    }

    return _incomeInCalendar(frequency, now, code);
  }

  /// Weekly vs monthly plan cadence from the latest recurring income row.
  RecurringFrequency preferredIncomeFrequencyFor(String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    // The calendar fallback reads this week and this month, so both starts
    // are part of the cache key.
    final now = deviceNow();
    final key = (
      code,
      CalendarPeriod.weekStart(now).millisecondsSinceEpoch,
      CalendarPeriod.monthStart(now).millisecondsSinceEpoch,
    );
    return _preferredFrequencies[key] ??= _computePreferredFrequency(code);
  }

  RecurringFrequency _computePreferredFrequency(String currencyCode) {
    WaffrTransaction? latestRecurringIncome;

    for (final income in incomesFor(currencyCode)) {
      if (income.frequency == RecurringFrequency.weekly ||
          income.frequency == RecurringFrequency.monthly) {
        latestRecurringIncome = income;
        break;
      }
    }

    if (latestRecurringIncome != null) {
      return latestRecurringIncome.frequency;
    }

    final weekly = _incomeInCalendar(
      RecurringFrequency.weekly,
      deviceNow(),
      currencyCode,
    );

    final monthly = _incomeInCalendar(
      RecurringFrequency.monthly,
      deviceNow(),
      currencyCode,
    );

    if (weekly > 0 && monthly <= 0) {
      return RecurringFrequency.weekly;
    }

    return RecurringFrequency.monthly;
  }

  /// [preferredIncomeFrequencyFor] the active currency.
  RecurringFrequency get preferredIncomeFrequency =>
      preferredIncomeFrequencyFor(_activeCode);

  /// Records an income. With [moveBalanceToSavings] the current balance is
  /// first moved to savings, which starts a new cycle. A weekly or monthly
  /// income also becomes the configured amount.
  Future<void> addIncome({
    required double amount,
    String? source,
    RecurringFrequency frequency = RecurringFrequency.none,
    bool moveBalanceToSavings = false,
    String? currencyCode,
  }) async {
    await ensureLoaded();

    final code = Currencies.normalize(currencyCode ?? _activeCode);
    final currentBalance = balanceFor(code);
    final currentGoal = activeGoalsFor(code).isEmpty
        ? null
        : activeGoalsFor(code).first;

    // Moving the leftover first closes the old cycle; the new income opens
    // the next one.
    if (moveBalanceToSavings && currentBalance > 0) {
      await _add(
        WaffrTransaction(
          id: WaffrTransaction.newId(),
          type: TransactionType.savingsIn,
          amount: currentBalance,
          currencyCode: code,
          note: TransactionStore._carryOverNote,
          dateTime: deviceNow(),
          transferKind: SavingsTransferKind.manual,
          goalId: currentGoal?.id,
          processedPeriodKey: TransactionStore.carryOverKey,
        ),
        persist: false,
        notify: false,
      );
    }

    final now = deviceNow();

    await _add(
      WaffrTransaction(
        id: WaffrTransaction.newId(),
        type: TransactionType.income,
        amount: amount,
        currencyCode: code,
        note: source,
        dateTime: now,
        frequency: frequency,
        periodKey: frequency == RecurringFrequency.none
            ? null
            : CalendarPeriod.keyFor(frequency, now),
      ),
      persist: false,
      notify: false,
    );

    // A recurring income also becomes the configured amount, so plans and
    // the home bar use it.
    if (frequency == RecurringFrequency.monthly ||
        frequency == RecurringFrequency.weekly) {
      _setOverride(frequency, amount, code);
    }

    final prefs = await AppPrefs.instance;
    await _persistAll(prefs);
    notifyListeners();
  }

  /// Updates the planned income figure without posting a new balance-changing row.
  Future<bool> setPreferredIncomeAmount({
    required RecurringFrequency frequency,
    required double amount,
    String? currencyCode,
  }) async {
    await ensureLoaded();

    if (!amount.isFinite || amount <= 0) {
      return false;
    }

    if (frequency != RecurringFrequency.monthly &&
        frequency != RecurringFrequency.weekly) {
      return false;
    }

    final code = Currencies.normalize(currencyCode ?? _activeCode);
    _setOverride(frequency, amount, code);
    await SyncDirty.mark(settings: true);
    final goalsChanged = _syncPeriodicGoalAmounts(frequency, amount, code);

    final prefs = await AppPrefs.instance;
    await _persistIncomeOverrides(prefs);
    if (goalsChanged) {
      await _persistGoals(prefs);
    }

    // Yield so Home/Report/Savings keep-alive tabs settle after the dialog closes.
    await Future<void>.delayed(Duration.zero);
    notifyListeners();

    return true;
  }

  /// Clears the settings override without deleting historical income rows.
  Future<bool> clearPreferredIncomeAmount({
    required RecurringFrequency frequency,
    String? currencyCode,
  }) async {
    await ensureLoaded();

    if (frequency != RecurringFrequency.monthly &&
        frequency != RecurringFrequency.weekly) {
      return false;
    }

    _clearOverride(
      frequency,
      Currencies.normalize(currencyCode ?? _activeCode),
    );
    await SyncDirty.mark(settings: true);

    final prefs = await AppPrefs.instance;
    await _persistIncomeOverrides(prefs);
    await Future<void>.delayed(Duration.zero);
    notifyListeners();
    return true;
  }

  double _incomeForPeriod(
    RecurringFrequency frequency,
    String periodKey,
    String currencyCode,
  ) {
    return incomesFor(currencyCode)
        .where(
          (item) => item.frequency == frequency && item.periodKey == periodKey,
        )
        .fold<double>(0, (sum, item) => sum + item.amount);
  }

  double _incomeInCalendar(
    RecurringFrequency frequency,
    DateTime date,
    String currencyCode,
  ) {
    final period = CalendarPeriod.ofFrequency(frequency, date);

    return incomesFor(currencyCode)
        .where(
          (item) =>
              item.frequency == frequency && period.contains(item.dateTime),
        )
        .fold<double>(0, (sum, item) => sum + item.amount);
  }

  void _setOverride(
    RecurringFrequency frequency,
    double amount,
    String currencyCode,
  ) {
    final code = Currencies.normalize(currencyCode);
    if (frequency == RecurringFrequency.monthly) {
      _monthlyIncomeByCurrency[code] = amount;
    } else if (frequency == RecurringFrequency.weekly) {
      _weeklyIncomeByCurrency[code] = amount;
    }
  }

  void _clearOverride(RecurringFrequency frequency, String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    if (frequency == RecurringFrequency.monthly) {
      _monthlyIncomeByCurrency.remove(code);
    } else if (frequency == RecurringFrequency.weekly) {
      _weeklyIncomeByCurrency.remove(code);
    }
  }

  double? _overrideFor(RecurringFrequency frequency, String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    return switch (frequency) {
      RecurringFrequency.monthly => _monthlyIncomeByCurrency[code],
      RecurringFrequency.weekly => _weeklyIncomeByCurrency[code],
      RecurringFrequency.none => null,
    };
  }

  String? _encodeIncomeOverrides() {
    final codes = {
      ..._monthlyIncomeByCurrency.keys,
      ..._weeklyIncomeByCurrency.keys,
    }..remove(defaultCurrencyCode);

    if (codes.isEmpty) return null;

    final payload = <String, Map<String, double>>{};
    for (final code in codes) {
      final monthly = _monthlyIncomeByCurrency[code];
      final weekly = _weeklyIncomeByCurrency[code];
      final entry = <String, double>{};
      if (monthly != null && monthly > 0) entry['monthly'] = monthly;
      if (weekly != null && weekly > 0) entry['weekly'] = weekly;
      if (entry.isNotEmpty) payload[code] = entry;
    }

    if (payload.isEmpty) return null;
    return jsonEncode(payload);
  }

  void _replaceNonDefaultIncomeOverrides(Object? raw) {
    final monthly = _monthlyIncomeByCurrency[defaultCurrencyCode];
    final weekly = _weeklyIncomeByCurrency[defaultCurrencyCode];
    _monthlyIncomeByCurrency.removeWhere(
      (code, _) => code != defaultCurrencyCode,
    );
    _weeklyIncomeByCurrency.removeWhere(
      (code, _) => code != defaultCurrencyCode,
    );
    if (monthly != null) {
      _monthlyIncomeByCurrency[defaultCurrencyCode] = monthly;
    }
    if (weekly != null) _weeklyIncomeByCurrency[defaultCurrencyCode] = weekly;
    _applyIncomeOverridesJson(raw);
  }

  void _applyIncomeOverridesJson(Object? raw) {
    Map<String, dynamic>? decoded;
    if (raw is Map) {
      decoded = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final value = jsonDecode(raw);
        if (value is Map) {
          decoded = Map<String, dynamic>.from(value);
        }
      } catch (_) {
        return;
      }
    }
    if (decoded == null) return;

    decoded.forEach((code, value) {
      if (value is! Map) return;
      final normalized = Currencies.normalize(code);
      if (normalized == defaultCurrencyCode) return;
      final monthly = parseMoney(value['monthly']);
      final weekly = parseMoney(value['weekly']);
      if (monthly != null && monthly > 0) {
        _monthlyIncomeByCurrency[normalized] = monthly;
      }
      if (weekly != null && weekly > 0) {
        _weeklyIncomeByCurrency[normalized] = weekly;
      }
    });
  }
}
