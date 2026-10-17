// RecurringExpense model: prefs round trip and validation, month stepping
// with end-of-month clamping, due dates, monthly cost, labels, copyWith and
// the source-id helpers.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/recurring_expense.dart';

RecurringExpense _bill({
  RecurringUnit unit = RecurringUnit.month,
  int intervalCount = 1,
  double amount = 90,
  DateTime? nextDueAt,
  DateTime? remindAt,
  bool remindOnIncome = false,
  DateTime? updatedAt,
}) => RecurringExpense(
  id: 'r1',
  amount: amount,
  currencyCode: 'USD',
  category: 'فواتير',
  paymentMethod: 'نقداً',
  note: 'إنترنت',
  unit: unit,
  intervalCount: intervalCount,
  createdAt: DateTime(2026, 1, 31, 9),
  nextDueAt: nextDueAt ?? DateTime(2026, 1, 31, 9),
  requiresConfirmation: true,
  remindAt: remindAt,
  remindOnIncome: remindOnIncome,
  updatedAt: updatedAt,
);

void main() {
  group('encode / decode', () {
    test('round trip keeps every field', () {
      final bill = _bill(
        remindAt: DateTime(2026, 2, 3),
        remindOnIncome: true,
        updatedAt: DateTime.utc(2026, 2),
      );
      final decoded = RecurringExpense.decode(bill.encode())!;
      expect(decoded.id, 'r1');
      expect(decoded.amount, 90);
      expect(decoded.currencyCode, 'USD');
      expect(decoded.category, 'فواتير');
      expect(decoded.paymentMethod, 'نقداً');
      expect(decoded.note, 'إنترنت');
      expect(decoded.unit, RecurringUnit.month);
      expect(decoded.intervalCount, 1);
      expect(decoded.createdAt, DateTime(2026, 1, 31, 9));
      expect(decoded.nextDueAt, DateTime(2026, 1, 31, 9));
      expect(decoded.enabled, isTrue);
      expect(decoded.requiresConfirmation, isTrue);
      expect(decoded.remindAt, DateTime(2026, 2, 3));
      expect(decoded.remindOnIncome, isTrue);
      expect(decoded.updatedAt, DateTime.utc(2026, 2));
    });

    test('rejects bad amount, interval, id or category', () {
      Map<String, Object?> base() => {
        'id': 'r',
        'amount': 10,
        'intervalCount': 1,
        'category': 'x',
      };
      expect(RecurringExpense.decode(jsonEncode(base())), isNotNull);
      expect(
        RecurringExpense.decode(jsonEncode({...base(), 'amount': 0})),
        isNull,
      );
      expect(
        RecurringExpense.decode(jsonEncode({...base(), 'intervalCount': 0})),
        isNull,
      );
      expect(
        RecurringExpense.decode(jsonEncode({...base(), 'id': ' '})),
        isNull,
      );
      expect(
        RecurringExpense.decode(jsonEncode({...base(), 'category': ''})),
        isNull,
      );
      expect(RecurringExpense.decode('[]'), isNull);
      expect(RecurringExpense.decode('{'), isNull);
    });

    test(
      'defaults: day unit, enabled, next due = created, legacy currency',
      () {
        final decoded = RecurringExpense.decode(
          jsonEncode({
            'id': 'r',
            'amount': 10,
            'intervalCount': 2,
            'category': 'x',
            'createdAt': '2026-03-01T10:00:00.000',
            'currency_code': 'eur',
            'enabled': null,
          }),
        )!;
        expect(decoded.unit, RecurringUnit.day);
        expect(decoded.enabled, isTrue, reason: 'only false disables');
        expect(decoded.nextDueAt, DateTime(2026, 3, 1, 10));
        expect(decoded.currencyCode, 'EUR');
        expect(decoded.paymentMethod, '');
        expect(decoded.note, isNull);
      },
    );
  });

  group('nextDueFrom', () {
    test('days and weeks add whole days', () {
      final from = DateTime(2026, 1, 30, 8);
      expect(
        RecurringExpense.nextDueFrom(from, RecurringUnit.day, 3),
        DateTime(2026, 2, 2, 8),
      );
      expect(
        RecurringExpense.nextDueFrom(from, RecurringUnit.week, 2),
        DateTime(2026, 2, 13, 8),
      );
    });

    test('months clamp to the last day and keep the time', () {
      final from = DateTime(2026, 1, 31, 9, 15);
      expect(
        RecurringExpense.nextDueFrom(from, RecurringUnit.month, 1),
        DateTime(2026, 2, 28, 9, 15),
      );
      expect(
        RecurringExpense.nextDueFrom(
          DateTime(2028, 1, 31),
          RecurringUnit.month,
          1,
        ),
        DateTime(2028, 2, 29),
      );
      expect(
        RecurringExpense.nextDueFrom(from, RecurringUnit.month, 3),
        DateTime(2026, 4, 30, 9, 15),
      );
      expect(
        RecurringExpense.nextDueFrom(
          DateTime(2026, 11, 15),
          RecurringUnit.month,
          14,
        ),
        DateTime(2028, 1, 15),
      );
    });

    test('a count below one is treated as one', () {
      expect(
        RecurringExpense.nextDueFrom(
          DateTime(2026, 1, 1),
          RecurringUnit.day,
          0,
        ),
        DateTime(2026, 1, 2),
      );
    });

    test('clamping drifts: Jan 31 -> Feb 28 -> Mar 28', () {
      var due = DateTime(2026, 1, 31);
      due = RecurringExpense.nextDueFrom(due, RecurringUnit.month, 1);
      due = RecurringExpense.nextDueFrom(due, RecurringUnit.month, 1);
      expect(due, DateTime(2026, 3, 28));
    });
  });

  group('dueDates', () {
    test('lists every passed charge oldest first, up to max', () {
      final bill = _bill(
        unit: RecurringUnit.day,
        nextDueAt: DateTime(2026, 5, 1, 9),
      );
      final dates = bill.dueDates(DateTime(2026, 5, 4, 9));
      expect(dates, [
        DateTime(2026, 5, 1, 9),
        DateTime(2026, 5, 2, 9),
        DateTime(2026, 5, 3, 9),
        DateTime(2026, 5, 4, 9),
      ]);
      expect(bill.dueDates(DateTime(2026, 5, 4, 9), max: 2), hasLength(2));
      expect(bill.dueDates(DateTime(2026, 5, 1, 8)), isEmpty);
      expect(bill.dueDates(DateTime(2027), max: 500), hasLength(245));
      expect(bill.dueDates(DateTime(2027)), hasLength(24));
    });
  });

  test('monthlyEquivalent per unit', () {
    expect(_bill(unit: RecurringUnit.day, amount: 10).monthlyEquivalent, 300);
    expect(
      _bill(unit: RecurringUnit.week, amount: 70).monthlyEquivalent,
      closeTo(300, 1e-9),
    );
    expect(_bill(amount: 90, intervalCount: 3).monthlyEquivalent, 30);
    expect(_bill(amount: 90, intervalCount: 0).monthlyEquivalent, 90);
  });

  test('interval descriptions and unit labels', () {
    expect(_bill().intervalDescription, 'كل شهر');
    expect(_bill(intervalCount: 3).intervalDescription, 'كل 3 أشهر');
    expect(
      _bill(unit: RecurringUnit.week, intervalCount: 2).intervalDescription,
      'كل 2 أسابيع',
    );
    expect(RecurringUnit.day.label, 'يوم');
    expect(RecurringUnit.day.plural, 'أيام');
  });

  group('copyWith', () {
    test('touch stamps updatedAt unless told not to', () {
      final bill = _bill(updatedAt: DateTime.utc(2020));
      final before = DateTime.now().toUtc();
      expect(bill.copyWith(amount: 5).updatedAt!.isBefore(before), isFalse);
      expect(
        bill.copyWith(amount: 5, touch: false).updatedAt,
        DateTime.utc(2020),
      );
      expect(bill.copyWith(amount: 5).amount, 5);
      expect(bill.copyWith(amount: 5).note, 'إنترنت');
    });

    test('clearReminder drops both postponement kinds', () {
      final bill = _bill(remindAt: DateTime(2026, 2), remindOnIncome: true);
      final cleared = bill.copyWith(clearReminder: true, remindOnIncome: true);
      expect(cleared.remindAt, isNull);
      expect(cleared.remindOnIncome, isFalse);

      final kept = bill.copyWith(enabled: false);
      expect(kept.remindAt, DateTime(2026, 2));
      expect(kept.remindOnIncome, isTrue);
      expect(kept.enabled, isFalse);
    });
  });

  group('source ids', () {
    test('recognize schedule charges and extract the id', () {
      expect(RecurringExpense.isRecurringSource('recurring:a:1'), isTrue);
      expect(RecurringExpense.isRecurringSource('shopping:a'), isFalse);
      expect(RecurringExpense.isRecurringSource(null), isFalse);
      expect(
        RecurringExpense.idFromSource('recurring:r_1:202601010900'),
        'r_1',
      );
      expect(RecurringExpense.idFromSource('recurring:onlyid'), 'onlyid');
      expect(RecurringExpense.idFromSource('recurring:'), isNull);
      expect(RecurringExpense.idFromSource('recurring::123'), ':123');
    });
  });

  test('syncUpdatedAt falls back to creation time', () {
    expect(_bill().syncUpdatedAt, DateTime(2026, 1, 31, 9).toUtc());
  });
}
