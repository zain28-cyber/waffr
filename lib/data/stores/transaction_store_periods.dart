// End-of-period work: periodic goal deductions and moving a finished
// period's leftover income to savings, each recorded once by token.

part of 'transaction_store.dart';

/// Work that happens when an income period ends: periodic goal
/// deductions and moving the period's leftover to savings.
extension DuePeriods on TransactionStore {
  /// Runs the end-of-period work for every finished period not processed
  /// yet, and notifies when anything changed.
  Future<void> processDuePeriods() async {
    await ensureLoaded();

    final prefs = await AppPrefs.instance;

    final changed = await _processDuePeriods(prefs);

    if (changed) {
      notifyListeners();
    }
  }

  // Periodic goal deductions plus leftover savings for completed income periods.
  Future<bool> _processDuePeriods(SharedPreferences prefs) async {
    if (_processingPeriods) {
      return false;
    }

    _processingPeriods = true;

    try {
      var changed = false;

      final now = deviceNow();

      // Periodic goals: one deduction per finished period since the goal was
      // created, up to its planned number of periods. A deduction the balance
      // cannot cover stops that goal until the next run.
      final periodicIds = [
        for (final goal in _allActiveGoals)
          if (goal.isPeriodic &&
              goal.allocateAmount != null &&
              goal.allocateAmount! > 0 &&
              goal.deductFrequency != RecurringFrequency.none)
            goal.id,
      ];

      for (final goalId in periodicIds) {
        final initialGoal = _goalById(goalId);

        if (initialGoal == null || initialGoal.isCompleted) {
          continue;
        }

        if (_percentPlanNeedsIncome(initialGoal)) {
          continue;
        }

        final keys = CalendarPeriod.completedKeysSince(
          initialGoal.deductFrequency,
          initialGoal.createdAt,
          now,
        );

        final maxCycles = initialGoal.cyclesFor(initialGoal.deductFrequency);

        var processedGoalCycles = 0;

        for (final key in keys) {
          final goal = _goalById(goalId);

          if (goal == null || goal.isCompleted) {
            break;
          }

          if (processedGoalCycles >= maxCycles) {
            break;
          }

          final token = _goalPeriodToken(goal.id, key);

          if (_processedPeriods.contains(token)) {
            processedGoalCycles++;
            continue;
          }

          final deducted = _deductGoalForPeriod(goal, key);

          if (!deducted) {
            break;
          }

          _processedPeriods.add(token);
          changed = true;
          changed |= _completeGoalIfNeeded();
          processedGoalCycles++;
        }
      }

      // Leftovers: every finished weekly or monthly income period, oldest
      // first, moves what was not spent to savings once.
      final leftoverKeys = <(RecurringFrequency, String, String)>{};

      for (final income in _transactions) {
        if (!income.isIncome) {
          continue;
        }

        if (income.frequency == RecurringFrequency.none) {
          continue;
        }

        final key = income.periodKey;

        if (key == null || key.isEmpty) {
          continue;
        }

        final period = CalendarPeriod.parseKey(key);

        if (period == null || !period.isComplete) {
          continue;
        }

        leftoverKeys.add((income.frequency, key, income.currencyCode));
      }

      final leftovers = leftoverKeys.toList()
        ..sort((a, b) => a.$2.compareTo(b.$2));

      for (final entry in leftovers) {
        final token = _leftoverToken(entry.$2, entry.$3);

        if (_markProcessed(token)) {
          changed = true;

          changed |= _transferLeftover(entry.$1, entry.$2, entry.$3);
        }
      }

      // Transfers may have completed goals; save once at the end.
      changed |= _completeGoalIfNeeded();

      if (changed) {
        await _persistAll(prefs);
      }

      return changed;
    } finally {
      _processingPeriods = false;
    }
  }

  // Percent monthly plans wait until configured monthly income exists.
  bool _percentPlanNeedsIncome(SavingsGoal goal) {
    if (goal.deductFrequency != RecurringFrequency.monthly) return false;
    final percent = goal.allocatePercent;
    if (percent == null || percent <= 0) return false;
    return !hasConfiguredMonthlyIncomeFor(goal.currencyCode);
  }

  bool _deductGoalForPeriod(SavingsGoal goal, String periodKey) {
    if (goal.isCompleted) {
      return true;
    }

    final amount = goal.allocateAmount ?? 0;

    if (amount <= 0) {
      return true;
    }

    if (!canDeduct(amount, currencyCode: goal.currencyCode)) {
      return false;
    }

    _transactions.add(
      WaffrTransaction(
        id: WaffrTransaction.newId(),
        type: TransactionType.savingsIn,
        amount: amount,
        currencyCode: goal.currencyCode,
        note: 'توفير دوري: ${goal.name}',
        dateTime: deviceNow(),
        transferKind: SavingsTransferKind.goalPeriodic,
        goalId: goal.id,
        processedPeriodKey: periodKey,
      ),
    );

    _sort();

    return true;
  }

  // Moves leftover period income into savings after expenses and goal deductions.
  bool _transferLeftover(
    RecurringFrequency frequency,
    String periodKey,
    String currencyCode,
  ) {
    final period = CalendarPeriod.parseKey(periodKey);

    if (period == null) {
      return false;
    }

    final code = Currencies.normalize(currencyCode);
    final periodIncome = _incomeForPeriod(frequency, periodKey, code);

    if (periodIncome <= 0) {
      return false;
    }

    // Leftover = the period's income − its expenses − its goal deductions,
    // never more than the balance.
    final periodExpense = expensesFor(code)
        .where((item) => period.contains(item.dateTime))
        .fold<double>(0, (sum, item) => sum + item.amount);

    final alreadySaved = _transactions
        .where(
          (item) =>
              item.currencyCode == code &&
              item.isSavingsIn &&
              item.processedPeriodKey == periodKey &&
              item.transferKind == SavingsTransferKind.goalPeriodic,
        )
        .fold<double>(0, (sum, item) => sum + item.amount);

    var leftover = periodIncome - periodExpense - alreadySaved;

    if (leftover <= 0) {
      return false;
    }

    final available = balanceFor(code);

    if (leftover > available) {
      leftover = available;
    }

    if (leftover <= 0) {
      return false;
    }

    // Tag the top goal so the leftover counts toward it.
    final leftoverGoal = activeGoalsFor(code).isEmpty
        ? null
        : activeGoalsFor(code).first;

    _transactions.add(
      WaffrTransaction(
        id: WaffrTransaction.newId(),
        type: TransactionType.savingsIn,
        amount: leftover,
        currencyCode: code,
        note: frequency == RecurringFrequency.weekly
            ? 'توفير نهاية الأسبوع'
            : 'توفير نهاية الشهر',
        dateTime: deviceNow(),
        transferKind: SavingsTransferKind.periodLeftover,
        goalId: leftoverGoal?.id,
        processedPeriodKey: periodKey,
      ),
    );

    _sort();

    return true;
  }

  bool _markProcessed(String token) {
    return _processedPeriods.add(token);
  }

  String _leftoverToken(String periodKey, String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    if (code == defaultCurrencyCode) {
      return 'leftover:$periodKey';
    }
    return 'leftover:$code:$periodKey';
  }

  String _goalPeriodToken(String goalId, String periodKey) {
    return 'goal:$goalId:$periodKey';
  }
}
