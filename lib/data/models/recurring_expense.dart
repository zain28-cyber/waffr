// Recurring expense schedule: interval units, model, and prefs serialization.

import 'dart:convert';

import 'package:waffr/data/models/currency.dart';

/// The step between charges of a recurring bill.
enum RecurringUnit {
  /// Every N days.
  day,

  /// Every N weeks.
  week,

  /// Every N months (same day, clamped to the month's end).
  month,
}

/// Arabic names of each [RecurringUnit].
extension RecurringUnitLabel on RecurringUnit {
  /// Singular ("شهر").
  String get label => switch (this) {
    RecurringUnit.day => 'يوم',
    RecurringUnit.week => 'أسبوع',
    RecurringUnit.month => 'شهر',
  };

  /// Plural ("أشهر").
  String get plural => switch (this) {
    RecurringUnit.day => 'أيام',
    RecurringUnit.week => 'أسابيع',
    RecurringUnit.month => 'أشهر',
  };
}

/// Scheduled expense; [nextDueAt] drives catch-up in the store. With
/// [requiresConfirmation] the charge waits for the user instead of posting.
class RecurringExpense {
  /// Local id (also the sync client id).
  final String id;

  /// Amount per charge.
  final double amount;

  /// Currency of the charges.
  final String currencyCode;

  /// Category of the posted expenses.
  final String category;

  /// Cash or card.
  final String paymentMethod;

  /// Optional note; also its name in notices.
  final String? note;

  /// Step unit.
  final RecurringUnit unit;

  /// Every how many [unit]s.
  final int intervalCount;

  /// When the schedule was added.
  final DateTime createdAt;

  /// The next charge not posted yet.
  final DateTime nextDueAt;

  /// False pauses the schedule.
  final bool enabled;

  /// True waits for the user's approval before posting.
  final bool requiresConfirmation;

  /// Postponed charge: remind again at [remindAt] or when income is added.
  final DateTime? remindAt;

  /// Remind again when an income is added.
  final bool remindOnIncome;

  /// Last change (UTC), for sync.
  final DateTime? updatedAt;

  /// A schedule.
  const RecurringExpense({
    required this.id,
    required this.amount,
    this.currencyCode = defaultCurrencyCode,
    required this.category,
    required this.paymentMethod,
    required this.unit,
    required this.intervalCount,
    required this.createdAt,
    required this.nextDueAt,
    this.note,
    this.enabled = true,
    this.requiresConfirmation = false,
    this.remindAt,
    this.remindOnIncome = false,
    this.updatedAt,
  });

  /// Last change for sync, falling back to creation time.
  DateTime get syncUpdatedAt => (updatedAt ?? createdAt).toUtc();

  /// Charges of this schedule whose date has passed, oldest first (capped).
  List<DateTime> dueDates(DateTime now, {int max = 24}) {
    final dates = <DateTime>[];
    var cursor = nextDueAt;
    while (!cursor.toUtc().isAfter(now.toUtc()) && dates.length < max) {
      dates.add(cursor);
      cursor = nextDueFrom(cursor, unit, intervalCount);
    }
    return dates;
  }

  /// Approximate cost per month, used for the obligations total.
  double get monthlyEquivalent {
    final count = intervalCount < 1 ? 1 : intervalCount;
    return switch (unit) {
      RecurringUnit.day => amount * 30 / count,
      RecurringUnit.week => amount * 30 / 7 / count,
      RecurringUnit.month => amount / count,
    };
  }

  /// Arabic "every N days/weeks/months" for notes and UI.
  String get intervalDescription {
    if (intervalCount <= 1) {
      return 'كل ${unit.label}';
    }

    return 'كل $intervalCount ${unit.plural}';
  }

  /// A copy with fields replaced; [clearReminder] drops a postponement
  /// and [touch] stamps [updatedAt] now.
  RecurringExpense copyWith({
    double? amount,
    String? currencyCode,
    DateTime? nextDueAt,
    bool? enabled,
    bool? requiresConfirmation,
    DateTime? remindAt,
    bool? remindOnIncome,
    bool clearReminder = false,
    DateTime? updatedAt,
    bool touch = true,
  }) {
    return RecurringExpense(
      id: id,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      category: category,
      paymentMethod: paymentMethod,
      note: note,
      unit: unit,
      intervalCount: intervalCount,
      createdAt: createdAt,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      enabled: enabled ?? this.enabled,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      remindAt: clearReminder ? null : (remindAt ?? this.remindAt),
      remindOnIncome: clearReminder
          ? false
          : (remindOnIncome ?? this.remindOnIncome),
      updatedAt: updatedAt ?? (touch ? DateTime.now().toUtc() : this.updatedAt),
    );
  }

  /// The prefs JSON shape.
  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'currencyCode': currencyCode,
    'category': category,
    'paymentMethod': paymentMethod,
    'note': note,
    'unit': unit.name,
    'intervalCount': intervalCount,
    'createdAt': createdAt.toIso8601String(),
    'nextDueAt': nextDueAt.toIso8601String(),
    'enabled': enabled,
    'requiresConfirmation': requiresConfirmation,
    'remindAt': remindAt?.toIso8601String(),
    'remindOnIncome': remindOnIncome,
    'updatedAt': syncUpdatedAt.toIso8601String(),
  };

  /// [toJson] as a string.
  String encode() => jsonEncode(toJson());

  /// Prefs decode; rejects non-positive amount or interval.
  static RecurringExpense? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final amount = (decoded['amount'] as num?)?.toDouble() ?? 0;
      final intervalCount = (decoded['intervalCount'] as num?)?.toInt() ?? 0;
      if (amount <= 0 || intervalCount <= 0) return null;

      final id = decoded['id']?.toString().trim() ?? '';
      final category = decoded['category']?.toString().trim() ?? '';
      if (id.isEmpty || category.isEmpty) return null;

      final createdAt =
          (DateTime.tryParse(decoded['createdAt']?.toString() ?? '') ??
                  DateTime.now())
              .toLocal();
      final nextDueAt =
          (DateTime.tryParse(decoded['nextDueAt']?.toString() ?? '') ??
                  createdAt)
              .toLocal();

      return RecurringExpense(
        id: id,
        amount: amount,
        currencyCode: Currencies.normalize(
          decoded['currencyCode']?.toString() ??
              decoded['currency_code']?.toString(),
        ),
        category: category,
        paymentMethod: decoded['paymentMethod']?.toString() ?? '',
        note: _text(decoded['note']),
        unit: _parseUnit(decoded['unit']?.toString()),
        intervalCount: intervalCount,
        createdAt: createdAt,
        nextDueAt: nextDueAt,
        enabled: decoded['enabled'] != false,
        requiresConfirmation: decoded['requiresConfirmation'] == true,
        remindAt: DateTime.tryParse(decoded['remindAt']?.toString() ?? '')
            ?.toLocal(),
        remindOnIncome: decoded['remindOnIncome'] == true,
        updatedAt: DateTime.tryParse(decoded['updatedAt']?.toString() ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  /// Advances [from] by count units; months clamp to the last valid day.
  static DateTime nextDueFrom(DateTime from, RecurringUnit unit, int count) {
    final safeCount = count < 1 ? 1 : count;

    switch (unit) {
      case RecurringUnit.day:
        return from.add(Duration(days: safeCount));
      case RecurringUnit.week:
        return from.add(Duration(days: 7 * safeCount));
      case RecurringUnit.month:
        final targetMonth = from.month + safeCount;
        final year = from.year + ((targetMonth - 1) ~/ 12);
        final month = ((targetMonth - 1) % 12) + 1;
        final lastDay = DateTime(year, month + 1, 0).day;
        final day = from.day > lastDay ? lastDay : from.day;
        return DateTime(
          year,
          month,
          day,
          from.hour,
          from.minute,
          from.second,
          from.millisecond,
        );
    }
  }

  static int _seq = 0;

  /// A fresh local id.
  static String newId() =>
      'r${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  /// Expenses posted by a schedule carry `recurring:<id>:<stamp>` as source.
  static const String sourcePrefix = 'recurring:';

  /// True when an expense was posted by a schedule.
  static bool isRecurringSource(String? sourceId) =>
      sourceId != null && sourceId.startsWith(sourcePrefix);

  /// Schedule id from an expense source id, or null for other expenses.
  static String? idFromSource(String? sourceId) {
    if (!isRecurringSource(sourceId)) return null;
    final rest = sourceId!.substring(sourcePrefix.length);
    final end = rest.lastIndexOf(':');
    final id = end <= 0 ? rest : rest.substring(0, end);
    return id.isEmpty ? null : id;
  }

  /// A stored unit name; days when unknown.
  static RecurringUnit _parseUnit(String? raw) {
    return switch (raw) {
      'week' => RecurringUnit.week,
      'month' => RecurringUnit.month,
      _ => RecurringUnit.day,
    };
  }

  /// Trimmed text, or null when blank.
  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
