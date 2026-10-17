// The alert rules of NotificationService. Each compares the ledger with
// the last snapshot and writes an alert when a value crossed a threshold,
// so reopening the app never repeats an alert.

part of 'notification_service.dart';

/// One method per alert kind; each returns true when it added an alert.
extension _NotificationRules on NotificationService {
  /// Seeds snapshot from the store and pretends completed goals already notified.
  void _applyBaseline(TransactionStore store) {
    _snapshot = _NotificationSnapshot.fromStore(store);

    for (final goal in store.goals) {
      if (!goal.isCompleted) continue;
      _eventKeys.add(_goalReachedKey(goal.id));
      for (final percent in NotificationThresholds.goalPercents) {
        _eventKeys.add(_goalProgressKey(goal.id, percent));
      }
    }
  }

  void _refreshSnapshot(TransactionStore store) {
    _snapshot = _NotificationSnapshot.fromStore(store);
  }

  /// Fires when the remaining balance drops through a
  /// [NotificationThresholds.remainingPercents] level, once per cycle.
  bool _evaluateBalance(TransactionStore store) {
    if (store.maxBalance <= 0) return false;

    final current = store.remainingRatio;
    final previous = _snapshot.remainingRatio;
    if (previous == null) return false;

    final crossed = <int>[];
    for (final percent in NotificationThresholds.remainingPercents) {
      final threshold = percent / 100;
      if (previous > threshold && current <= threshold) {
        crossed.add(percent);
      }
    }
    if (crossed.isEmpty) return false;

    final percent = crossed.reduce((a, b) => a < b ? a : b);
    final cycle = _incomeCycle(store);
    final left = '${formatMoney(store.balance)} $currencyLabel';
    final income = '${formatMoney(store.maxBalance)} $currencyLabel';
    return _tryAdd(
      type: NotificationType.balanceWarning,
      title: percent <= 10 ? 'رصيدك على وشك النفاد' : 'بقي ربع رصيدك',
      message: percent <= 10
          ? 'بقي $left فقط من أصل $income.'
          : 'المتاح الآن $left من أصل $income. راجع مصروفاتك حتى الدخل القادم.',
      eventKey: 'balanceWarning:$percent:$cycle',
      metadata: {'percent': '$percent', 'cycle': cycle},
    );
  }

  /// Smart alert: at the recent pace the balance runs out before the next
  /// income. At most once a week per cycle, and only with enough history.
  bool _evaluateForecast(TransactionStore store) {
    if (!SmartSettings.instance.alerts || store.balance <= 0) return false;
    final facts = SmartFacts(
      now: deviceNow(),
      currencySymbol: currencyLabel,
      expenses: store.expenses,
      incomes: store.incomes,
      savingsTransfers: const [],
      balance: store.balance,
      monthlyIncome: store.configuredMonthlyIncome,
      incomeFrequency: store.preferredIncomeFrequency,
      hasRecurringIncome: store.hasRecurringIncome,
      savingsBalance: 0,
      goals: const [],
      completedGoals: 0,
      obligations: const [],
      pendingShopping: 0,
      streakCount: 0,
      usageStartedAt: null,
    );
    final untilIncome = facts.daysUntilIncome;
    final runway = facts.runwayDays;
    if (untilIncome == null || untilIncome < 3 || runway == null) return false;
    if (facts.weeksOfHistory < 1 || facts.loggedLast30 < 5) return false;
    final gap = (untilIncome - runway).ceil();
    if (gap < 2) return false;

    final dailyLimit = store.balance / untilIncome;
    final cycle = _incomeCycle(store);
    final week = CalendarPeriod.weeklyKey(facts.now);
    return _tryAdd(
      type: NotificationType.balanceWarning,
      title: 'قد ينفد رصيدك قبل الدخل',
      message:
          'بوتيرتك الحالية سينفد رصيدك قبل الدخل القادم بنحو '
          '${Ar.days.of(gap)}. حاول ألا تتجاوز '
          '${formatMoney(dailyLimit)} $currencyLabel يومياً.',
      eventKey: 'balanceForecast:$cycle:$week',
      metadata: {'cycle': cycle, 'gapDays': '$gap'},
    );
  }

  /// Fires when cycle spending climbs through a
  /// [NotificationThresholds.spendingPercents] share of the cycle's 100%.
  bool _evaluateSpending(TransactionStore store) {
    if (store.maxBalance <= 0) return false;

    final current = store.cycleSpent / store.maxBalance;
    final previous = _snapshot.spentRatio;
    if (previous == null) return false;

    final crossed = <int>[];
    for (final percent in NotificationThresholds.spendingPercents) {
      final threshold = percent / 100;
      if (previous < threshold && current >= threshold) {
        crossed.add(percent);
      }
    }
    if (crossed.isEmpty) return false;

    final percent = crossed.reduce((a, b) => a > b ? a : b);
    final cycle = _incomeCycle(store);
    return _tryAdd(
      type: NotificationType.highSpending,
      title: 'صرفت \u2066$percent%\u2069 من رصيد الدورة',
      message:
          'صرفت ${formatMoney(store.cycleSpent)} من '
          '${formatMoney(store.maxBalance)} $currencyLabel، '
          'والمتاح الآن ${formatMoney(store.balance)} $currencyLabel.',
      eventKey: 'highSpending:$percent:$cycle',
      metadata: {'percent': '$percent', 'cycle': cycle},
    );
  }

  /// Goal reached at 100%, or progress through a
  /// [NotificationThresholds.goalPercents] level.
  bool _evaluateGoals(TransactionStore store) {
    var changed = false;

    for (final goal in store.goals) {
      final current = store.goalRatio(goal);
      final previous = _snapshot.goalRatios[goal.id];

      if (goal.isCompleted) {
        changed |= _tryAdd(
          type: NotificationType.goalReached,
          title: 'اكتمل هدف ${Ar.quote(goal.name)}',
          message:
              'جمعت ${formatMoney(goal.targetAmount)} '
              '${currencyLabelFor(goal.currencyCode)} المطلوبة لهذا الهدف.',
          eventKey: _goalReachedKey(goal.id),
          relatedId: goal.id,
          metadata: {'goalName': goal.name, 'percent': '100'},
          createdAt: goal.completedAt,
        );
        continue;
      }

      if (previous == null) continue;

      final crossed = <int>[];
      for (final percent in NotificationThresholds.goalPercents) {
        final threshold = percent / 100;
        if (previous < threshold && current >= threshold) {
          crossed.add(percent);
        }
      }
      if (crossed.isEmpty) continue;

      final percent = crossed.reduce((a, b) => a > b ? a : b);
      final symbol = currencyLabelFor(goal.currencyCode);
      changed |= _tryAdd(
        type: NotificationType.goalProgress,
        title: 'هدف ${Ar.quote(goal.name)}: \u2066$percent%\u2069',
        message:
            'وفّرت ${formatMoney(store.currentSaved(goal))} من '
            '${formatMoney(goal.targetAmount)} $symbol.',
        eventKey: _goalProgressKey(goal.id, percent),
        relatedId: goal.id,
        metadata: {'goalName': goal.name, 'percent': '$percent'},
      );
    }

    return changed;
  }

  /// Notifies for new period-leftover or goal-periodic savings transfers.
  bool _evaluateTransfers(TransactionStore store) {
    var changed = false;

    for (final item in store.savingsTransfers) {
      if (!item.isSavingsIn) continue;
      if (_snapshot.knownTransactionIds.contains(item.id)) continue;

      final kind = item.transferKind;
      if (kind != SavingsTransferKind.periodLeftover &&
          kind != SavingsTransferKind.goalPeriodic) {
        continue;
      }

      final periodLabel = _periodAdjective(item);
      final goalName = _goalName(store, item.goalId);
      final amount =
          '${formatMoney(item.amount)} ${currencyLabelFor(item.currencyCode)}';
      final weekly = periodLabel == 'الأسبوعية';

      changed |= _tryAdd(
        type: NotificationType.savingsTransferred,
        title: 'أُضيف $amount إلى التوفير',
        message: kind == SavingsTransferKind.goalPeriodic
            ? 'الدفعة الدورية${goalName == null ? '' : ' لهدف $goalName'}.'
            : 'المتبقي من دخل ${weekly ? 'الأسبوع' : 'الشهر'} الماضي'
                  '${goalName == null ? '' : '، ضمن هدف $goalName'}.',
        eventKey: 'savingsTransfer:${item.id}',
        relatedId: item.id,
        metadata: {
          'amount': '${item.amount}',
          'periodType': kind == SavingsTransferKind.goalPeriodic
              ? 'goalPeriodic'
              : (item.processedPeriodKey?.startsWith('w:') == true
                    ? 'weekly'
                    : 'monthly'),
          'periodKey': ?item.processedPeriodKey,
          'goalName': ?goalName,
        },
        createdAt: item.dateTime,
      );
    }

    return changed;
  }

  /// Period-completed alerts when leftover was processed without a transfer row.
  bool _evaluatePeriods(TransactionStore store) {
    var changed = false;

    for (final token in store.processedPeriodTokens) {
      if (!token.startsWith('leftover:')) continue;
      if (_snapshot.knownProcessedTokens.contains(token)) continue;

      final periodKey = token.substring('leftover:'.length);
      if (periodKey.isEmpty) continue;

      final alreadyTransferred = _items.any(
        (item) =>
            item.type == NotificationType.savingsTransferred &&
            item.metadata['periodKey'] == periodKey,
      );
      if (alreadyTransferred) continue;

      final hasTransfer = store.savingsTransfers.any(
        (item) =>
            item.isSavingsIn &&
            item.transferKind == SavingsTransferKind.periodLeftover &&
            item.processedPeriodKey == periodKey,
      );
      if (hasTransfer) continue;

      final weekly = periodKey.contains('w:');
      final span = weekly ? 'الأسبوع' : 'الشهر';
      changed |= _tryAdd(
        type: NotificationType.recurringPeriodCompleted,
        title: 'انتهى $span دون توفير',
        message: 'لم يتبقَّ من دخل $span الماضي مبلغ يُنقل إلى التوفير.',
        eventKey: 'periodCompleted:$periodKey',
        relatedId: periodKey,
        metadata: {
          'periodKey': periodKey,
          'periodType': weekly ? 'weekly' : 'monthly',
        },
      );
    }

    return changed;
  }

  /// Flags expenses ≥ 2× the average of earlier ones (needs >4 expenses).
  bool _evaluateLargeExpenses(TransactionStore store) {
    final expenses = store.expenses;
    if (expenses.length <= NotificationThresholds.minExpensesForLarge) {
      return false;
    }

    var changed = false;
    final chronological = [...expenses]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    for (var i = 0; i < chronological.length; i++) {
      final expense = chronological[i];
      if (_snapshot.knownTransactionIds.contains(expense.id)) continue;
      if (i < NotificationThresholds.minExpensesForLarge) continue;
      // Scheduled bills have their own notice and are expected amounts.
      if (RecurringExpense.isRecurringSource(expense.sourceId)) continue;

      final prior = chronological.sublist(0, i);
      final average =
          prior.fold<double>(0, (sum, item) => sum + item.amount) /
          prior.length;
      if (average <= 0) continue;
      if (expense.amount <
          average * NotificationThresholds.largeExpenseMultiplier) {
        continue;
      }

      changed |= _tryAdd(
        type: NotificationType.largeExpense,
        title: 'مصروف أعلى من المعتاد',
        message:
            '${formatMoney(expense.amount)} '
            '${currencyLabelFor(expense.currencyCode)} على '
            '${Ar.category(categoryFor(expense.category).label)}، أي ضعف متوسط مصروفاتك أو أكثر.',
        eventKey: 'largeExpense:${expense.id}',
        relatedId: expense.id,
        metadata: {
          'amount': '${expense.amount}',
          'category': ?expense.category,
        },
        createdAt: expense.dateTime,
      );
    }

    return changed;
  }

  String _incomeCycle(TransactionStore store) => 'cycle:${store.cycleKey}';

  String _goalReachedKey(String goalId) => 'goalReached:$goalId';

  String _goalProgressKey(String goalId, int percent) =>
      'goalProgress:$goalId:$percent';

  String? _goalName(TransactionStore store, String? goalId) {
    if (goalId == null) return null;
    for (final goal in store.goals) {
      if (goal.id == goalId) return goal.name;
    }
    return null;
  }

  /// Arabic weekly/monthly adjective from period key or recurring frequency.
  String? _periodAdjective(WaffrTransaction item) {
    final key = item.processedPeriodKey;
    if (key != null) {
      if (key.startsWith('w:')) return 'الأسبوعية';
      if (key.startsWith('m:')) return 'الشهرية';
    }
    return switch (item.frequency) {
      RecurringFrequency.weekly => 'الأسبوعية',
      RecurringFrequency.monthly => 'الشهرية',
      RecurringFrequency.none => null,
    };
  }
}
