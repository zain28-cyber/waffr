// Counts and lifetime spending/saving for the profile. One pass, no charts.

import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

/// The profile's stat tiles: how many records of each kind, and lifetime
/// money spent and saved in the active currency.
class ProfileSnapshot {
  /// Expenses in every currency.
  final int expenseCount;

  /// Incomes in every currency.
  final int incomeCount;

  /// Goals, active and completed.
  final int goalCount;

  /// Transfers into savings in every currency.
  final int savingsCount;

  /// Lifetime spending in the active currency.
  final double spent;

  /// Lifetime transfers into savings in the active currency.
  final double saved;

  /// A snapshot with the given figures.
  const ProfileSnapshot({
    required this.expenseCount,
    required this.incomeCount,
    required this.goalCount,
    required this.savingsCount,
    required this.spent,
    required this.saved,
  });

  /// Counts every record once; money only for the active currency.
  factory ProfileSnapshot.fromStore(TransactionStore store) {
    final code = CurrencyStore.instance.activeCode;
    var expenseCount = 0;
    var incomeCount = 0;
    var savingsCount = 0;
    var spent = 0.0;
    var saved = 0.0;

    for (final item in store.transactions) {
      if (item.isExpense) {
        expenseCount++;
      } else if (item.isIncome) {
        incomeCount++;
      } else if (item.isSavingsIn) {
        savingsCount++;
      }

      if (item.currencyCode != code) continue;
      if (item.isExpense) {
        spent += item.amount;
      } else if (item.isSavingsIn) {
        saved += item.amount;
      }
    }

    return ProfileSnapshot(
      expenseCount: expenseCount,
      incomeCount: incomeCount,
      goalCount: store.goals.length,
      savingsCount: savingsCount,
      spent: spent,
      saved: saved,
    );
  }
}

/// Earliest ledger or goal date, used when usage start was never stored.
DateTime? earliestUsageDate(TransactionStore store) {
  DateTime? earliest;
  for (final item in store.transactions) {
    final local = item.dateTime.toLocal();
    if (earliest == null || local.isBefore(earliest)) earliest = local;
  }
  for (final goal in store.goals) {
    final local = goal.createdAt.toLocal();
    if (earliest == null || local.isBefore(earliest)) earliest = local;
  }
  return earliest;
}
