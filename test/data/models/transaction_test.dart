// WaffrTransaction: prefs JSON round trip, decode fallbacks for missing or
// bad fields, copyWith, type flags and the enum name parsers.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/transaction.dart';

void main() {
  final when = DateTime(2026, 3, 4, 10, 30);

  WaffrTransaction full() => WaffrTransaction(
    id: 'tx1',
    type: TransactionType.savingsIn,
    amount: 125.5,
    currencyCode: 'USD',
    dateTime: when,
    category: 'طعام',
    paymentMethod: 'نقداً',
    note: 'ملاحظة',
    sourceId: 'shopping:a',
    frequency: RecurringFrequency.weekly,
    periodKey: 'w:2026-02-28',
    transferKind: SavingsTransferKind.goalPeriodic,
    goalId: 'g1',
    processedPeriodKey: 'm:2026-02',
    updatedAt: DateTime.utc(2026, 3, 5),
  );

  group('encode / decode', () {
    test('round trip keeps every field', () {
      final decoded = WaffrTransaction.decode(full().encode())!;

      expect(decoded.id, 'tx1');
      expect(decoded.type, TransactionType.savingsIn);
      expect(decoded.amount, 125.5);
      expect(decoded.currencyCode, 'USD');
      expect(decoded.dateTime, when);
      expect(decoded.category, 'طعام');
      expect(decoded.paymentMethod, 'نقداً');
      expect(decoded.note, 'ملاحظة');
      expect(decoded.sourceId, 'shopping:a');
      expect(decoded.frequency, RecurringFrequency.weekly);
      expect(decoded.periodKey, 'w:2026-02-28');
      expect(decoded.transferKind, SavingsTransferKind.goalPeriodic);
      expect(decoded.goalId, 'g1');
      expect(decoded.processedPeriodKey, 'm:2026-02');
      expect(decoded.updatedAt, DateTime.utc(2026, 3, 5));
    });

    test('toJson stamps updatedAt from the event time when missing', () {
      final row = WaffrTransaction(
        id: 'x',
        type: TransactionType.expense,
        amount: 1,
        dateTime: DateTime.utc(2026, 1, 2, 3),
      );
      expect(row.syncUpdatedAt, DateTime.utc(2026, 1, 2, 3));
      expect(row.toJson()['updatedAt'], '2026-01-02T03:00:00.000Z');
      expect(row.toJson()['transferKind'], isNull);
      expect(row.toJson()['currencyCode'], 'SYP');
    });

    test('rejects non-positive amounts, non-objects and bad JSON', () {
      expect(
        WaffrTransaction.decode(jsonEncode({'id': 'a', 'amount': 0})),
        isNull,
      );
      expect(
        WaffrTransaction.decode(jsonEncode({'id': 'a', 'amount': -3})),
        isNull,
      );
      expect(WaffrTransaction.decode(jsonEncode({'id': 'a'})), isNull);
      expect(WaffrTransaction.decode('[1, 2]'), isNull);
      expect(WaffrTransaction.decode('not json'), isNull);
      // A string amount is a type error, caught as invalid.
      expect(
        WaffrTransaction.decode(jsonEncode({'id': 'a', 'amount': '5'})),
        isNull,
      );
    });

    test('missing fields fall back to safe defaults', () {
      final before = DateTime.now();
      final decoded = WaffrTransaction.decode(
        jsonEncode({'amount': 7, 'type': 'bogus', 'note': '   '}),
      )!;

      expect(decoded.id, isNotEmpty);
      expect(decoded.type, TransactionType.expense);
      expect(decoded.currencyCode, 'SYP');
      expect(decoded.note, isNull, reason: 'blank text becomes null');
      expect(decoded.frequency, RecurringFrequency.none);
      expect(decoded.transferKind, isNull);
      expect(decoded.updatedAt, isNull);
      expect(decoded.dateTime.isBefore(before), isFalse);
    });

    test('accepts the legacy currency_code key and normalizes case', () {
      final decoded = WaffrTransaction.decode(
        jsonEncode({'id': 'a', 'amount': 1, 'currency_code': ' eur '}),
      )!;
      expect(decoded.currencyCode, 'EUR');
    });

    test('dates come back in the device zone', () {
      final decoded = WaffrTransaction.decode(
        jsonEncode({
          'id': 'a',
          'amount': 1,
          'dateTime': '2026-01-01T12:00:00.000Z',
        }),
      )!;
      expect(decoded.dateTime.isUtc, isFalse);
      expect(decoded.dateTime.toUtc(), DateTime.utc(2026, 1, 1, 12));
    });
  });

  test('copyWith only replaces the event time and currency', () {
    final original = full();
    final moved = original.copyWith(
      dateTime: DateTime(2027),
      currencyCode: 'EUR',
    );

    expect(moved.dateTime, DateTime(2027));
    expect(moved.currencyCode, 'EUR');
    expect(moved.id, original.id);
    expect(moved.goalId, original.goalId);
    expect(moved.updatedAt, original.updatedAt);
    expect(original.copyWith().encode(), original.encode());
  });

  test('type flags match the type', () {
    WaffrTransaction of(TransactionType type) =>
        WaffrTransaction(id: 'x', type: type, amount: 1, dateTime: when);

    expect(of(TransactionType.income).isIncome, isTrue);
    expect(of(TransactionType.expense).isExpense, isTrue);
    expect(of(TransactionType.savingsIn).isSavingsIn, isTrue);
    expect(of(TransactionType.savingsOut).isSavingsOut, isTrue);
    expect(of(TransactionType.income).isExpense, isFalse);
  });

  test('frequency and transfer kind parsers', () {
    expect(WaffrTransaction.frequencyFrom('weekly'), RecurringFrequency.weekly);
    expect(
      WaffrTransaction.frequencyFrom('monthly'),
      RecurringFrequency.monthly,
    );
    expect(WaffrTransaction.frequencyFrom(null), RecurringFrequency.none);
    expect(WaffrTransaction.frequencyFrom('yearly'), RecurringFrequency.none);

    for (final kind in SavingsTransferKind.values) {
      expect(WaffrTransaction.transferKindFrom(kind.name), kind);
    }
    expect(WaffrTransaction.transferKindFrom('other'), isNull);
  });

  test('new ids are unique', () {
    final ids = {for (var i = 0; i < 50; i++) WaffrTransaction.newId()};
    expect(ids, hasLength(50));
  });
}
