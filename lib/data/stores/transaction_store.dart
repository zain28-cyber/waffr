// Sole source of truth for transactions, operating balance, and savings
// goals. The ledger lives in SharedPreferences as JSON; the operating
// balance is always income − expense − net savings.
//
// The store is one class whose behavior is split by topic into part files,
// each an extension on TransactionStore:
//
//   transaction_store_queries.dart      rows, goals, totals, balances
//   transaction_store_cycle.dart        the balance cycle (the home bar's 100%)
//   transaction_store_income.dart       incomes and configured income amounts
//   transaction_store_entries.dart      expenses and savings moves
//   transaction_store_goals.dart        savings goals and periodic plans
//   transaction_store_periods.dart      end-of-period deductions and leftovers
//   transaction_store_persistence.dart  loading, migrating and saving
//   transaction_store_sync.dart         merging the server's copy
//
// Importing this file brings in all of them.

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/sync/profile_sync.dart';
import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/sync/sync_mapper.dart';
import 'package:waffr/core/sync/sync_merge.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/models/calendar_period.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/currency_store.dart';

part 'transaction_store_cycle.dart';
part 'transaction_store_entries.dart';
part 'transaction_store_goals.dart';
part 'transaction_store_income.dart';
part 'transaction_store_periods.dart';
part 'transaction_store_persistence.dart';
part 'transaction_store_queries.dart';
part 'transaction_store_sync.dart';

/// The ledger: incomes, expenses, savings transfers and goals, per
/// currency, with derived balances cached until the next change.
///
/// A singleton [ChangeNotifier]. It loads from prefs once
/// ([ensureLoaded]), serves memory after that, and notifies listeners on
/// every change. The behavior lives in the extensions listed above.
class TransactionStore extends ChangeNotifier {
  TransactionStore._();

  /// The app-wide ledger.
  static final TransactionStore instance = TransactionStore._();

  /// Prefs key of the ledger rows (one JSON string each).
  static const String transactionsKey = 'transactions';

  /// Prefs key of the last saved balance (read by home widgets).
  static const String balanceKey = 'balance';

  /// Prefs key of the last saved cycle 100%.
  static const String maxBalanceKey = 'max_balance';

  /// Prefs key of the goals (one JSON string each).
  static const String savingsGoalsKey = 'savings_goals';

  /// Prefs key of the single goal older versions kept.
  static const String legacySavingsGoalKey = 'savings_goal';

  /// Prefs key of the period tokens already processed.
  static const String processedPeriodsKey = 'processed_periods';

  /// Prefs key of the last saved savings balance.
  static const String savingsBalanceKey = 'savings_balance';

  /// Prefs key of the configured monthly income in SYP.
  static const String monthlyIncomeKey = 'monthly_income_amount';

  /// Prefs key of the configured weekly income in SYP.
  static const String weeklyIncomeKey = 'weekly_income_amount';

  /// Prefs key of configured incomes in other currencies (JSON).
  static const String incomeOverridesByCurrencyKey =
      'income_overrides_by_currency';

  /// Pre-JSON expense rows: amount|description|isoDate.
  static const String legacyExpensesKey = 'expenses';

  final List<WaffrTransaction> _transactions = [];

  final List<SavingsGoal> _goals = [];

  final Set<String> _processedPeriods = {};

  final Map<String, Future<WaffrTransaction?>> _pendingExpenseSources = {};

  Future<void>? _loader;

  bool _loaded = false;

  bool _processingPeriods = false;

  bool _listeningToCurrency = false;

  final Map<String, double> _monthlyIncomeByCurrency = {};

  final Map<String, double> _weeklyIncomeByCurrency = {};

  /// Hook after prefs hydrate, before due-period processing.
  Future<void> Function()? onHydrated;

  /// True once the ledger was read from prefs.
  bool get isLoaded => _loaded;

  /// Tokens of the periods already processed (synced with settings).
  Set<String> get processedPeriodTokens => Set.unmodifiable(_processedPeriods);

  String get _activeCode => CurrencyStore.instance.activeCode;

  /// Loads the ledger once; later calls return the same future.
  Future<void> ensureLoaded() => _loader ??= _load();

  /// Newest first. A read-only view of the ledger, not a copy: iterate it
  /// right away instead of keeping it across an await.
  List<WaffrTransaction> get transactions => _transactionsView;

  late final List<WaffrTransaction> _transactionsView = UnmodifiableListView(
    _transactions,
  );

  /// processedPeriodKey on the transfer that moves leftover balance to
  /// savings while adding a new income.
  static const String carryOverKey = 'carry';

  /// Note on that carry-over transfer (also how older rows are recognized).
  static const String _carryOverNote = 'نقل الرصيد الحالي إلى التوفير';

  /// Drops in-memory state so the next ensureLoaded re-reads prefs.
  void resetCache() {
    _transactions.clear();
    _touch();
    _goals.clear();
    _processedPeriods.clear();
    _pendingExpenseSources.clear();
    _monthlyIncomeByCurrency.clear();
    _weeklyIncomeByCurrency.clear();

    _loaded = false;
    _loader = null;

    notifyListeners();
  }

  /// Newest first; every change goes through here, so it also drops caches.
  void _sort() {
    _touch();
    _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  // ---------------------------------------------------------------------
  // Derived-value caches. Screens read balances and the cycle start many
  // times per build; these are computed once per ledger change instead of
  // rescanning (and re-sorting) every transaction on every read.
  // ---------------------------------------------------------------------

  final Map<(TransactionType, String), double> _totals = {};

  final Map<String, DateTime?> _cycleStarts = {};

  final Map<(String, int, int), RecurringFrequency> _preferredFrequencies = {};

  final Map<(String, DateTime?), double> _maxBalances = {};

  final Map<(String, DateTime, DateTime), double> _savingsNets = {};

  /// Drops the caches. Called whenever the ledger changes.
  void _touch() {
    _totals.clear();
    _cycleStarts.clear();
    _preferredFrequencies.clear();
    _maxBalances.clear();
    _savingsNets.clear();
  }

  @override
  void notifyListeners() {
    _touch();
    super.notifyListeners();
  }
}
