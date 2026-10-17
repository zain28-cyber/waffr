// Small builders for ledger rows and SmartFacts, so tests state only the
// fields they care about.

import 'package:waffr/core/insights/smart/smart_facts.dart';
import 'package:waffr/data/models/transaction.dart';

int _ids = 0;

/// A unique id for test rows.
String testId([String prefix = 'id']) => '$prefix${_ids++}';

/// An expense of [amount] at [at].
WaffrTransaction expenseAt(
  double amount,
  DateTime at, {
  String? id,
  String category = 'طعام',
  String? note,
  String? paymentMethod,
  String? sourceId,
  String currencyCode = 'SYP',
  DateTime? updatedAt,
}) => WaffrTransaction(
  id: id ?? testId('e'),
  type: TransactionType.expense,
  amount: amount,
  dateTime: at,
  category: category,
  note: note,
  paymentMethod: paymentMethod,
  sourceId: sourceId,
  currencyCode: currencyCode,
  updatedAt: updatedAt,
);

/// An income of [amount] at [at].
WaffrTransaction incomeAt(
  double amount,
  DateTime at, {
  String? id,
  RecurringFrequency frequency = RecurringFrequency.none,
  String? periodKey,
  String currencyCode = 'SYP',
}) => WaffrTransaction(
  id: id ?? testId('i'),
  type: TransactionType.income,
  amount: amount,
  dateTime: at,
  frequency: frequency,
  periodKey: periodKey,
  currencyCode: currencyCode,
);

/// A savings transfer; [out] makes it a withdrawal.
WaffrTransaction transferAt(
  double amount,
  DateTime at, {
  String? id,
  bool out = false,
  String? goalId,
  SavingsTransferKind? kind,
  String? processedPeriodKey,
  String currencyCode = 'SYP',
}) => WaffrTransaction(
  id: id ?? testId('t'),
  type: out ? TransactionType.savingsOut : TransactionType.savingsIn,
  amount: amount,
  dateTime: at,
  goalId: goalId,
  transferKind:
      kind ?? (out ? SavingsTransferKind.withdraw : SavingsTransferKind.manual),
  processedPeriodKey: processedPeriodKey,
  currencyCode: currencyCode,
);

/// SmartFacts with neutral defaults; override what the test needs.
SmartFacts buildFacts({
  required DateTime now,
  String symbol = 'ل.س',
  List<WaffrTransaction> expenses = const [],
  List<WaffrTransaction> incomes = const [],
  List<WaffrTransaction> transfers = const [],
  double balance = 0,
  double? monthlyIncome,
  RecurringFrequency incomeFrequency = RecurringFrequency.monthly,
  bool hasRecurringIncome = false,
  double savingsBalance = 0,
  List<GoalFact> goals = const [],
  int completedGoals = 0,
  List<ObligationFact> obligations = const [],
  int pendingShopping = 0,
  int streakCount = 0,
  DateTime? usageStartedAt,
}) {
  return SmartFacts(
    now: now,
    currencySymbol: symbol,
    expenses: expenses,
    incomes: incomes,
    savingsTransfers: transfers,
    balance: balance,
    monthlyIncome: monthlyIncome,
    incomeFrequency: incomeFrequency,
    hasRecurringIncome: hasRecurringIncome,
    savingsBalance: savingsBalance,
    goals: goals,
    completedGoals: completedGoals,
    obligations: obligations,
    pendingShopping: pendingShopping,
    streakCount: streakCount,
    usageStartedAt: usageStartedAt,
  );
}
