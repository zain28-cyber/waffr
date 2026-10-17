// Savings goals: progress, creation, periodic plans, ordering, and
// marking goals complete.

part of 'transaction_store.dart';

/// Savings goals: progress, creation, periodic plans, order and completion.
extension GoalPlans on TransactionStore {
  /// Same as [goalProgress]; kept for the screens that read it.
  double currentSaved(SavingsGoal goal) => goalProgress(goal);

  /// Progress from tagged transfers plus legacy untagged ones attributed by date.
  double goalProgress(SavingsGoal goal) {
    if (goal.isCompleted) {
      return goal.completedAmount ?? goal.targetAmount;
    }

    var saved = 0.0;
    var withdrawn = 0.0;

    for (final item in _transactions) {
      if (item.dateTime.isBefore(goal.createdAt)) {
        continue;
      }

      if (!_countsTowardGoal(item, goal)) {
        continue;
      }

      if (item.isSavingsIn) {
        saved += item.amount;
      }

      if (item.isSavingsOut) {
        withdrawn += item.amount;
      }
    }

    final progress = saved - withdrawn;

    return progress < 0 ? 0 : progress;
  }

  /// Progress as a share of the target, 0..1.
  double goalRatio(SavingsGoal goal) {
    if (goal.targetAmount <= 0) {
      return 0;
    }

    return (goalProgress(goal) / goal.targetAmount).clamp(0.0, 1.0);
  }

  // Keeps a periodic contribution from exceeding the reference salary.
  double _capToIncome(double amount, double income) {
    if (!amount.isFinite || amount <= 0) return 0;
    if (income > 0 && amount > income) return income;
    return amount;
  }

  // Recomputes allocateAmount on percent-based periodic goals for this income.
  bool _syncPeriodicGoalAmounts(
    RecurringFrequency frequency,
    double income,
    String currencyCode,
  ) {
    var changed = false;
    final code = Currencies.normalize(currencyCode);

    for (var i = 0; i < _goals.length; i++) {
      final goal = _goals[i];
      if (goal.isCompleted || !goal.isPeriodic) continue;
      if (goal.currencyCode != code) continue;
      if (goal.deductFrequency != frequency) continue;

      final percent = goal.allocatePercent;
      if (percent == null || percent <= 0) continue;

      final cappedPercent = percent.clamp(0, 100).toDouble();
      final perPeriod = _capToIncome(income * cappedPercent / 100, income);
      if (!perPeriod.isFinite || perPeriod <= 0) continue;
      if (perPeriod == goal.allocateAmount && cappedPercent == percent) {
        continue;
      }

      _goals[i] = goal.copyWith(
        allocatePercent: cappedPercent,
        allocateAmount: perPeriod,
        touch: true,
      );
      changed = true;
    }

    return changed;
  }

  /// Appends a new goal at the end of the list (lowest priority).
  Future<bool> createGoal({
    required String name,
    required double targetAmount,
    required GoalDurationPreset duration,
    double? allocatePercent,
    double? allocateAmount,
    RecurringFrequency deductFrequency = RecurringFrequency.monthly,
    bool isPeriodic = false,
    int? durationCount,
    String? currencyCode,
  }) async {
    await ensureLoaded();

    if (name.trim().isEmpty || targetAmount <= 0) {
      return false;
    }

    final now = deviceNow();
    final code = Currencies.normalize(currencyCode ?? _activeCode);
    // A periodic amount is capped at the reference income and needs a
    // cadence and a number of periods.
    final reference = deductFrequency == RecurringFrequency.none
        ? 0.0
        : referenceIncome(deductFrequency, currencyCode: code);
    final cappedPercent = allocatePercent?.clamp(0, 100).toDouble();
    final periodicAmount = _capToIncome(allocateAmount ?? 0, reference);

    if (isPeriodic) {
      if (periodicAmount <= 0) {
        return false;
      }

      if (deductFrequency == RecurringFrequency.none) {
        return false;
      }

      if (durationCount == null || durationCount <= 0) {
        return false;
      }
    }

    // New goals go last (lowest priority).
    _goals.add(
      SavingsGoal(
        id: SavingsGoal.newId(),
        name: name.trim(),
        targetAmount: targetAmount,
        currencyCode: code,
        createdAt: now,
        duration: duration,
        allocatePercent: cappedPercent,
        allocateAmount: isPeriodic ? periodicAmount : null,
        deductFrequency: deductFrequency,
        isPeriodic: isPeriodic && periodicAmount > 0,
        durationCount: durationCount != null && durationCount > 0
            ? durationCount
            : null,
        priority: _goals.length,
      ),
    );

    _reindexPriorities();

    final prefs = await AppPrefs.instance;

    await _persistGoals(prefs);

    notifyListeners();

    return true;
  }

  /// Creates or updates the top active periodic plan from the plans screen.
  Future<bool> applyPeriodicPlan({
    required double percent,
    required GoalDurationPreset duration,
    required RecurringFrequency frequency,
    required double income,
    String? currencyCode,
  }) async {
    await ensureLoaded();

    if (percent <= 0 || income <= 0) {
      return false;
    }

    final code = Currencies.normalize(currencyCode ?? _activeCode);
    // Per-period amount from the percent of income; the target is that
    // amount times the number of periods.
    final cycles = duration.cycleCount(frequency);

    final cappedPercent = percent.clamp(0, 100).toDouble();
    final perPeriod = _capToIncome(income * cappedPercent / 100, income);

    if (perPeriod <= 0 || cycles <= 0) {
      return false;
    }

    final target = perPeriod * cycles;

    final existing = activeGoalsFor(code).isEmpty
        ? null
        : activeGoalsFor(code).first;

    // The top active goal becomes the plan; without one, a new plan goal.
    if (existing != null) {
      final index = _goals.indexWhere((goal) => goal.id == existing.id);

      if (index < 0) {
        return false;
      }

      _goals[index] = existing.copyWith(
        allocatePercent: cappedPercent,
        allocateAmount: perPeriod,
        deductFrequency: frequency,
        isPeriodic: true,
        durationCount: cycles,
        touch: true,
      );
    } else {
      _goals.add(
        SavingsGoal(
          id: SavingsGoal.newId(),
          name: 'توفير ${cappedPercent.round()}٪',
          targetAmount: target,
          currencyCode: code,
          createdAt: deviceNow(),
          duration: duration,
          allocatePercent: cappedPercent,
          allocateAmount: perPeriod,
          deductFrequency: frequency,
          isPeriodic: true,
          durationCount: cycles,
          priority: _goals.length,
        ),
      );
    }

    _reindexPriorities();

    final prefs = await AppPrefs.instance;

    await _persistGoals(prefs);

    notifyListeners();

    return true;
  }

  /// Deletes the goal record only; savings cash stays in the savings balance.
  Future<bool> deleteGoal(String id) async {
    await ensureLoaded();

    final index = _goals.indexWhere((goal) => goal.id == id);

    if (index < 0) {
      return false;
    }

    _goals.removeAt(index);
    await SyncTombstones.instance.add(SyncCollection.savingsGoals, id);
    _reindexPriorities();

    final prefs = await AppPrefs.instance;

    await _persistGoals(prefs);

    notifyListeners();

    return true;
  }

  /// Reorders active goals; [newIndex] is the final slot after removal.
  Future<void> reorderActiveGoals(int oldIndex, int newIndex) async {
    await ensureLoaded();

    final code = _activeCode;
    final active = activeGoalsFor(code).toList();

    if (oldIndex < 0 || oldIndex >= active.length) {
      return;
    }

    if (newIndex < 0 || newIndex >= active.length) {
      return;
    }

    if (oldIndex == newIndex) {
      return;
    }

    // Move within the active list, then write it back into the active
    // slots of the full list (completed and other-currency goals stay put).
    final moved = active.removeAt(oldIndex);
    active.insert(newIndex, moved);

    var activeIndex = 0;
    for (var i = 0; i < _goals.length; i++) {
      if (_goals[i].isCompleted) {
        continue;
      }
      if (_goals[i].currencyCode != code) {
        continue;
      }

      _goals[i] = active[activeIndex++];
    }

    _reindexPriorities();

    // Notify before the write so a dragged goal does not snap back while
    // the list rebuilds from the old order.
    notifyListeners();

    final prefs = await AppPrefs.instance;

    await _persistGoals(prefs);
  }

  bool _completeGoalIfNeeded() {
    var changed = false;

    for (final goal in List<SavingsGoal>.from(_allActiveGoals)) {
      final progress = goalProgress(goal);

      if (progress + 0.0001 < goal.targetAmount) {
        continue;
      }

      final index = _goals.indexWhere((item) => item.id == goal.id);

      if (index < 0) {
        continue;
      }

      _goals[index] = goal.copyWith(
        completedAt: deviceNow(),
        completedAmount: progress > goal.targetAmount
            ? progress
            : goal.targetAmount,
        touch: true,
      );
      changed = true;
    }

    if (changed) {
      _reindexPriorities();
    }

    return changed;
  }

  bool _countsTowardGoal(WaffrTransaction item, SavingsGoal goal) {
    if (!item.isSavingsIn && !item.isSavingsOut) {
      return false;
    }

    if (item.currencyCode != goal.currencyCode) {
      return false;
    }

    final taggedId = item.goalId;

    if (taggedId != null && taggedId.isNotEmpty) {
      return taggedId == goal.id;
    }

    return _legacyGoalIdFor(item.dateTime) == goal.id;
  }

  // Untagged old transfers attach to the oldest goal still open at that time.
  String? _legacyGoalIdFor(DateTime at) {
    SavingsGoal? best;

    for (final goal in _goals) {
      if (goal.createdAt.isAfter(at)) {
        continue;
      }

      if (goal.completedAt != null && !goal.completedAt!.isAfter(at)) {
        continue;
      }

      if (best == null || goal.createdAt.isBefore(best.createdAt)) {
        best = goal;
      }
    }

    return best?.id;
  }

  SavingsGoal? _goalById(String id) {
    for (final goal in _goals) {
      if (goal.id == id) {
        return goal;
      }
    }

    return null;
  }

  void _reindexPriorities() {
    for (var i = 0; i < _goals.length; i++) {
      if (_goals[i].priority != i) {
        _goals[i] = _goals[i].copyWith(priority: i);
      }
    }
  }

  // Sorts by priority, keeping storage order when priority values tie.
  bool _normalizeGoalPriorities() {
    if (_goals.isEmpty) {
      return false;
    }

    final original = List<SavingsGoal>.from(_goals);

    final indexed =
        [for (var i = 0; i < _goals.length; i++) (index: i, goal: _goals[i])]
          ..sort((a, b) {
            final byPriority = a.goal.priority.compareTo(b.goal.priority);
            if (byPriority != 0) return byPriority;
            return a.index.compareTo(b.index);
          });

    var changed = false;

    for (var i = 0; i < indexed.length; i++) {
      final next = indexed[i].goal.priority == i
          ? indexed[i].goal
          : indexed[i].goal.copyWith(priority: i);

      if (original[i].id != next.id || original[i].priority != next.priority) {
        changed = true;
      }

      _goals[i] = next;
    }

    return changed;
  }
}
