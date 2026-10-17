// Money movement types and the WaffrTransaction record stored as JSON in prefs.

import 'dart:convert';

import 'package:waffr/data/models/currency.dart';

/// The kind of money movement a ledger row records.
enum TransactionType {
  /// Money received.
  income,

  /// Money spent.
  expense,

  /// Balance moved into savings.
  savingsIn,

  /// Savings moved back to the balance.
  savingsOut,
}

/// Income cadence: none means no automatic savings rollover for that entry.
enum RecurringFrequency {
  /// A one-off income.
  none,

  /// Paid every week.
  weekly,

  /// Paid every month.
  monthly,
}

/// Why a savings transfer happened.
enum SavingsTransferKind {
  /// The leftover of a finished income period, moved automatically.
  periodLeftover,

  /// A periodic plan's deduction for one period.
  goalPeriodic,

  /// The user moved money by hand.
  manual,

  /// The user took money back from savings.
  withdraw,
}

/// One ledger row: income, expense, or savings in/out, with optional period/goal links.
class WaffrTransaction {
  /// Local id (also the sync client id).
  final String id;

  /// What kind of movement this is.
  final TransactionType type;

  /// Positive amount.
  final double amount;

  /// Currency of the amount.
  final String currencyCode;

  /// Expense category label.
  final String? category;

  /// Cash or card, for expenses.
  final String? paymentMethod;

  /// Optional note.
  final String? note;

  /// Where an automatic expense came from (`recurring:…`, `shopping:…`),
  /// so it is never posted twice.
  final String? sourceId;

  /// When it happened, in the device zone.
  final DateTime dateTime;

  /// Income cadence.
  final RecurringFrequency frequency;

  /// Income period (`w:…` / `m:…`) of a recurring income.
  final String? periodKey;

  /// Why a savings transfer happened.
  final SavingsTransferKind? transferKind;

  /// Goal a savings transfer counts toward.
  final String? goalId;

  /// Period an automatic transfer was made for.
  final String? processedPeriodKey;

  /// Last change (UTC), for sync.
  final DateTime? updatedAt;

  /// A ledger row.
  const WaffrTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.currencyCode = defaultCurrencyCode,
    required this.dateTime,
    this.category,
    this.paymentMethod,
    this.note,
    this.sourceId,
    this.frequency = RecurringFrequency.none,
    this.periodKey,
    this.transferKind,
    this.goalId,
    this.processedPeriodKey,
    this.updatedAt,
  });

  /// Last change for sync, falling back to the event time.
  DateTime get syncUpdatedAt => (updatedAt ?? dateTime).toUtc();

  /// A copy with a new event time or currency.
  WaffrTransaction copyWith({DateTime? dateTime, String? currencyCode}) {
    return WaffrTransaction(
      id: id,
      type: type,
      amount: amount,
      currencyCode: currencyCode ?? this.currencyCode,
      dateTime: dateTime ?? this.dateTime,
      category: category,
      paymentMethod: paymentMethod,
      note: note,
      sourceId: sourceId,
      frequency: frequency,
      periodKey: periodKey,
      transferKind: transferKind,
      goalId: goalId,
      processedPeriodKey: processedPeriodKey,
      updatedAt: updatedAt,
    );
  }

  /// True for incomes.
  bool get isIncome => type == TransactionType.income;

  /// True for expenses.
  bool get isExpense => type == TransactionType.expense;

  /// True for moves into savings.
  bool get isSavingsIn => type == TransactionType.savingsIn;

  /// True for moves out of savings.
  bool get isSavingsOut => type == TransactionType.savingsOut;

  /// The prefs JSON shape.
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'currencyCode': currencyCode,
    'category': category,
    'paymentMethod': paymentMethod,
    'note': note,
    'sourceId': sourceId,
    'dateTime': dateTime.toIso8601String(),
    'frequency': frequency.name,
    'periodKey': periodKey,
    'transferKind': transferKind?.name,
    'goalId': goalId,
    'processedPeriodKey': processedPeriodKey,
    'updatedAt': syncUpdatedAt.toIso8601String(),
  };

  /// [toJson] as a string.
  String encode() => jsonEncode(toJson());

  /// Prefs decode; rejects non-positive amounts. Accepts legacy currency_code.
  static WaffrTransaction? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final amount = (decoded['amount'] as num?)?.toDouble() ?? 0;
      if (amount <= 0) return null;

      return WaffrTransaction(
        id: _text(decoded['id']) ?? newId(),
        type: _parseType(_text(decoded['type'])),
        amount: amount,
        currencyCode: Currencies.normalize(
          _text(decoded['currencyCode']) ?? _text(decoded['currency_code']),
        ),
        category: _text(decoded['category']),
        paymentMethod: _text(decoded['paymentMethod']),
        note: _text(decoded['note']),
        sourceId: _text(decoded['sourceId']),
        dateTime:
            (DateTime.tryParse(_text(decoded['dateTime']) ?? '') ??
                    DateTime.now())
                .toLocal(),
        frequency: _parseFrequency(_text(decoded['frequency'])),
        periodKey: _text(decoded['periodKey']),
        transferKind: _parseTransferKind(_text(decoded['transferKind'])),
        goalId: _text(decoded['goalId']),
        processedPeriodKey: _text(decoded['processedPeriodKey']),
        updatedAt: DateTime.tryParse(_text(decoded['updatedAt']) ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  static int _seq = 0;

  /// A fresh local id.
  static String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  /// A stored type name; expense when unknown.
  static TransactionType _parseType(String? raw) {
    return switch (raw) {
      'income' => TransactionType.income,
      'savingsIn' => TransactionType.savingsIn,
      'savingsOut' => TransactionType.savingsOut,
      _ => TransactionType.expense,
    };
  }

  /// Reads a stored or synced frequency name.
  static RecurringFrequency frequencyFrom(String? raw) => _parseFrequency(raw);

  /// Reads a stored or synced transfer kind name.
  static SavingsTransferKind? transferKindFrom(String? raw) =>
      _parseTransferKind(raw);

  static RecurringFrequency _parseFrequency(String? raw) {
    return switch (raw) {
      'weekly' => RecurringFrequency.weekly,
      'monthly' => RecurringFrequency.monthly,
      _ => RecurringFrequency.none,
    };
  }

  static SavingsTransferKind? _parseTransferKind(String? raw) {
    return switch (raw) {
      'periodLeftover' => SavingsTransferKind.periodLeftover,
      'goalPeriodic' => SavingsTransferKind.goalPeriodic,
      'manual' => SavingsTransferKind.manual,
      'withdraw' => SavingsTransferKind.withdraw,
      _ => null,
    };
  }

  /// Trimmed text, or null when blank.
  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
