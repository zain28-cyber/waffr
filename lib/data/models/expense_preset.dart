// A saved expense the user can reuse from the star button on the expense sheet.

import 'dart:convert';

import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/data/models/currency.dart';
import 'package:waffr/data/models/recurring_expense.dart';

/// A saved expense the user can reuse from the star on the expense sheet.
class ExpensePreset {
  /// Local id (also the sync client id).
  final String id;

  /// Amount as typed, before [multiplier] is applied.
  final double amount;

  /// How many times [amount] is posted (×1–×10).
  final int multiplier;

  /// Currency of the amount.
  final String currencyCode;

  /// Category label.
  final String category;

  /// Cash or card.
  final String paymentMethod;

  /// Optional note.
  final String? note;

  /// True when it creates a recurring bill.
  final bool recurring;

  /// Recurrence unit, when [recurring].
  final RecurringUnit unit;

  /// Every how many [unit]s, when [recurring].
  final int intervalCount;

  /// When it was saved; newest first in the list.
  final DateTime createdAt;

  /// Last change (UTC), for sync.
  final DateTime? updatedAt;

  /// A saved expense.
  const ExpensePreset({
    required this.id,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    required this.createdAt,
    this.multiplier = 1,
    this.currencyCode = defaultCurrencyCode,
    this.note,
    this.recurring = false,
    this.unit = RecurringUnit.month,
    this.intervalCount = 1,
    this.updatedAt,
  });

  /// Last change for sync, falling back to creation time.
  DateTime get syncUpdatedAt => (updatedAt ?? createdAt).toUtc();

  /// Amount that the expense will post (typed amount times the multiplier).
  double get total => amount * multiplier;

  /// Same expense details, ignoring ids and timestamps.
  bool sameDetailsAs(ExpensePreset other) {
    return amount == other.amount &&
        multiplier == other.multiplier &&
        currencyCode == other.currencyCode &&
        category == other.category &&
        paymentMethod == other.paymentMethod &&
        (note ?? '') == (other.note ?? '') &&
        recurring == other.recurring &&
        (!recurring ||
            (unit == other.unit && intervalCount == other.intervalCount));
  }

  static int _seq = 0;

  /// A fresh local id.
  static String newId() =>
      'p${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  /// The prefs JSON shape.
  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'multiplier': multiplier,
    'currencyCode': currencyCode,
    'category': category,
    'paymentMethod': paymentMethod,
    'note': note,
    'recurring': recurring,
    'unit': unit.name,
    'intervalCount': intervalCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': syncUpdatedAt.toIso8601String(),
  };

  /// [toJson] as a string.
  String encode() => jsonEncode(toJson());

  /// Reads prefs JSON; null when invalid.
  static ExpensePreset? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return _fromMap(
        id: decoded['id'],
        amount: decoded['amount'],
        multiplier: decoded['multiplier'],
        currencyCode: decoded['currencyCode'],
        category: decoded['category'],
        paymentMethod: decoded['paymentMethod'],
        note: decoded['note'],
        recurring: decoded['recurring'],
        unit: decoded['unit'],
        intervalCount: decoded['intervalCount'],
        createdAt: DateTime.tryParse(decoded['createdAt']?.toString() ?? '')
            ?.toLocal(),
        updatedAt: DateTime.tryParse(decoded['updatedAt']?.toString() ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  /// The /sync `expense_presets` row.
  Map<String, dynamic> toSyncJson() => {
    'client_id': id,
    'amount': amount.toString(),
    'multiplier': multiplier,
    'currency_code': currencyCode,
    'category': category,
    'payment_method': paymentMethod,
    'note': note,
    'recurring': recurring,
    'unit': unit.name,
    'interval_count': intervalCount,
    'created_at': toSyncIso(createdAt),
    'updated_at': toSyncIso(syncUpdatedAt),
  };

  /// Reads a /sync row; null when invalid.
  static ExpensePreset? fromSync(Map<String, dynamic> raw) {
    return _fromMap(
      id: raw['client_id'] ?? raw['id'],
      amount: raw['amount'],
      multiplier: raw['multiplier'],
      currencyCode: raw['currency_code'] ?? raw['currencyCode'],
      category: raw['category'],
      paymentMethod: raw['payment_method'] ?? raw['paymentMethod'],
      note: raw['note'],
      recurring: raw['recurring'],
      unit: raw['unit'],
      intervalCount: raw['interval_count'] ?? raw['intervalCount'],
      createdAt: parseEventLocal(raw['created_at'] ?? raw['createdAt']),
      updatedAt: parseSyncDate(raw['updated_at'] ?? raw['updatedAt']),
    );
  }

  // Rejects rows without an id, a category or a positive amount.
  static ExpensePreset? _fromMap({
    required Object? id,
    required Object? amount,
    required Object? multiplier,
    required Object? currencyCode,
    required Object? category,
    required Object? paymentMethod,
    required Object? note,
    required Object? recurring,
    required Object? unit,
    required Object? intervalCount,
    required DateTime? createdAt,
    required DateTime? updatedAt,
  }) {
    final cleanId = id?.toString().trim() ?? '';
    final cleanCategory = category?.toString().trim() ?? '';
    final value = amount is num
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '') ?? 0;
    if (cleanId.isEmpty || cleanCategory.isEmpty || value <= 0) return null;

    final times = multiplier is num
        ? multiplier.toInt()
        : int.tryParse(multiplier?.toString() ?? '') ?? 1;
    final interval = intervalCount is num
        ? intervalCount.toInt()
        : int.tryParse(intervalCount?.toString() ?? '') ?? 1;
    final cleanNote = note?.toString().trim() ?? '';

    return ExpensePreset(
      id: cleanId,
      amount: value,
      multiplier: times.clamp(1, 10),
      currencyCode: Currencies.normalize(currencyCode?.toString()),
      category: cleanCategory,
      paymentMethod: paymentMethod?.toString() ?? '',
      note: cleanNote.isEmpty ? null : cleanNote,
      recurring: recurring == true,
      unit: switch (unit?.toString()) {
        'day' => RecurringUnit.day,
        'week' => RecurringUnit.week,
        _ => RecurringUnit.month,
      },
      intervalCount: interval.clamp(1, 99),
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt,
    );
  }
}
