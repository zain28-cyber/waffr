// Read-only views of the ledger: rows and goals per currency, totals,
// balances, and per-window savings.

part of 'transaction_store.dart';

/// Read-only views of the ledger: rows per currency, goals, totals and
/// balances.
extension TransactionQueries on TransactionStore {
  /// Expenses in the active currency, newest first.
  List<WaffrTransaction> get expenses => expensesFor(_activeCode);

  /// Incomes in the active currency, newest first.
  List<WaffrTransaction> get incomes => incomesFor(_activeCode);

  /// Savings moves in the active currency, newest first.
  List<WaffrTransaction> get savingsTransfers =>
      savingsTransfersFor(_activeCode);

  /// Expenses in [currencyCode], newest first.
  List<WaffrTransaction> expensesFor(String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    return _transactions
        .where((item) => item.isExpense && item.currencyCode == code)
        .toList(growable: false);
  }

  /// Incomes in [currencyCode], newest first.
  List<WaffrTransaction> incomesFor(String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    return _transactions
        .where((item) => item.isIncome && item.currencyCode == code)
        .toList(growable: false);
  }

  /// Savings moves in and out in [currencyCode], newest first.
  List<WaffrTransaction> savingsTransfersFor(String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    return _transactions
        .where(
          (item) =>
              (item.isSavingsIn || item.isSavingsOut) &&
              item.currencyCode == code,
        )
        .toList(growable: false);
  }

  /// Every goal in every currency, priority order.
  List<SavingsGoal> get goals => List.unmodifiable(_goals);

  /// Incomplete goals for the active currency, priority order (0 = top).
  List<SavingsGoal> get activeGoals => activeGoalsFor(_activeCode);

  /// Incomplete goals in [currencyCode], priority order.
  List<SavingsGoal> activeGoalsFor(String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    return _goals
        .where((goal) => !goal.isCompleted && goal.currencyCode == code)
        .toList(growable: false);
  }

  List<SavingsGoal> get _allActiveGoals =>
      _goals.where((goal) => !goal.isCompleted).toList(growable: false);

  /// Highest-priority active goal that has a periodic deduction plan.
  SavingsGoal? get activePeriodicGoal {
    for (final goal in activeGoals) {
      if (goal.isPeriodic) return goal;
    }
    return null;
  }

  /// True when an active goal saves automatically each period.
  bool get hasActivePeriodicPlan => activePeriodicGoal != null;

  /// [completedGoalsFor] the active currency.
  List<SavingsGoal> get completedGoals => completedGoalsFor(_activeCode);

  /// Completed goals in [currencyCode], most recent first.
  List<SavingsGoal> completedGoalsFor(String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    return _goals
        .where((goal) => goal.isCompleted && goal.currencyCode == code)
        .toList(growable: false)
      ..sort(
        (a, b) => (b.completedAt ?? b.createdAt).compareTo(
          a.completedAt ?? a.createdAt,
        ),
      );
  }

  /// All expenses in the active currency.
  double get totalExpense => totalExpenseFor(_activeCode);

  /// All income in [currencyCode].
  double totalIncomeFor(String currencyCode) =>
      _totalOf(TransactionType.income, currencyCode);

  /// All expenses in [currencyCode].
  double totalExpenseFor(String currencyCode) =>
      _totalOf(TransactionType.expense, currencyCode);

  /// All moves into savings in [currencyCode].
  double totalSavingsInFor(String currencyCode) =>
      _totalOf(TransactionType.savingsIn, currencyCode);

  /// All moves out of savings in [currencyCode].
  double totalSavingsOutFor(String currencyCode) =>
      _totalOf(TransactionType.savingsOut, currencyCode);

  /// Cash currently parked in savings (in − out, floored at 0).
  double get savingsBalance => savingsBalanceFor(_activeCode);

  /// Cash parked in savings in [currencyCode] (in − out, floored at 0).
  double savingsBalanceFor(String currencyCode) {
    final value =
        totalSavingsInFor(currencyCode) - totalSavingsOutFor(currencyCode);

    return value < 0 ? 0 : value;
  }

  /// Spendable operating balance; excludes money already moved to savings.
  double get balance => balanceFor(_activeCode);

  /// Spendable balance in [currencyCode]: income − expenses − savings.
  double balanceFor(String currencyCode) {
    return totalIncomeFor(currencyCode) -
        totalExpenseFor(currencyCode) -
        savingsBalanceFor(currencyCode);
  }

  /// True when [amount] fits without going negative.
  bool canDeduct(double amount, {String? currencyCode}) {
    final code = Currencies.normalize(currencyCode ?? _activeCode);
    return amount > 0 && amount <= balanceFor(code);
  }

  /// Expense totals by category, largest first.
  List<({String category, double amount})> expensesByCategory({
    String? currencyCode,
  }) {
    final code = Currencies.normalize(currencyCode ?? _activeCode);
    final totals = <String, double>{};

    for (final expense in expensesFor(code)) {
      final category = expense.category ?? 'أخرى';

      totals[category] = (totals[category] ?? 0) + expense.amount;
    }

    final entries = totals.entries
        .map((entry) => (category: entry.key, amount: entry.value))
        .toList();

    entries.sort((a, b) => b.amount.compareTo(a.amount));

    return entries;
  }

  /// Net savings inside [start, end): in minus out, floored at 0. Cached per
  /// window, because the savings pager asks for each page and its previous
  /// page on every rebuild.
  double savingsNetDuring(
    DateTime start,
    DateTime end, {
    String? currencyCode,
  }) {
    final code = Currencies.normalize(currencyCode ?? _activeCode);
    return _savingsNets[(code, start, end)] ??= _computeSavingsNet(
      code,
      start,
      end,
    );
  }

  double _computeSavingsNet(String code, DateTime start, DateTime end) {
    var incoming = 0.0;
    var outgoing = 0.0;

    for (final item in _transactions) {
      if (item.currencyCode != code) {
        continue;
      }
      if (item.dateTime.isBefore(start) || !item.dateTime.isBefore(end)) {
        continue;
      }

      if (item.isSavingsIn) {
        incoming += item.amount;
      }

      if (item.isSavingsOut) {
        outgoing += item.amount;
      }
    }

    final net = incoming - outgoing;

    return net < 0 ? 0 : net;
  }

  double _totalOf(TransactionType type, String currencyCode) {
    final code = Currencies.normalize(currencyCode);
    return _totals.putIfAbsent(
      (type, code),
      () => _transactions
          .where((item) => item.type == type && item.currencyCode == code)
          .fold<double>(0, (sum, item) => sum + item.amount),
    );
  }
}
